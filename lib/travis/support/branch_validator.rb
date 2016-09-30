require 'gh'

module Travis
  module Scheduler
    class BranchValidator < Struct.new(:branch_name, :repository)
      attr_reader :last_response_status, :last_error_message

      def valid?
        # return false immediately if the branch name doesn't look like a branch
        return false unless valid_branch_name?

        # if the branch exists in the DB, we can return true
        return true if branch_exists_in_the_db?

        # if branch doesn't exist, hit GitHub's API
        return branch_exists_on_github?
      end

      def branch_exists_in_the_db?
        Branch.where(repository_id: repository.id, name: branch_name).exists?
      end

      def branch_exists_on_github?
        candidates = repository.users.where("github_oauth_token IS NOT NULL").
                                      order("updated_at DESC")

        return unless candidates.exists?

        # we will check only first 3 most recently updated users
        candidates[0..4].any? do |user|
          begin
            result = nil

            GH.with(token: user.github_oauth_token) do
              result = !!fetch_branch
            end

            result
          rescue GH::TokenInvalid
            # do nothing and just go to the next user
          end
        end
      end

      def fetch_branch
        tries ||= 1
        Metriks.timer('enqueue.branch_validator.github_fetch_branch').time do
          GH["/repos/#{repository.slug}/branches/#{URI.escape(branch_name)}"]
        end
      rescue GH::TokenInvalid
        raise
      rescue GH::Error => e
        # we can just return false if it's a 404 or 403
        if  e.info[:response_status] == 404 || e.info[:response_status] == 403
          if e.info
            @last_response_status = e.info[:response_status]
            @last_error_message = e.message
          end

          return false
        end

        if tries >= 3
          # if it's any other 4xx error we're probably doing something wrong,
          # bubble the error up
          if e.info[:response_status] >= 400 && e.info[:response_status] < 500
            raise
          end
        else
          tries += 1
          retry
        end
      end

      def valid_branch_name?
        regexp = /
        ^(?!\/)  # can't begin with a slash
         (?!.*\/\.) # path component can't begin with a dot
         (?!.*\.\.) # can't contain 2 dots
         (?!.*\/\/) # can't include double slash
         [^\040\177[[:space:]]~^:?*\[\\\{@]+ # allow everything other then these chars
         (?<!\.lock) # can't end with .lock
         (?<![\/.])$ # can't end with \/ or .
        /x

        branch_name =~ regexp
      end
    end
  end
end
