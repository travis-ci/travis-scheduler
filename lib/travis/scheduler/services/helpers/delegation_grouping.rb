module Travis
  module Scheduler
    module Services
      module Helpers
        
        # Allow delegation of an account to determine the number of runnable
        # jobs based on another account. Relevant for organizations that have
        # multiple GitHub accounts but only want to have one subscription.
        #
        # In the configuration, this can be set by using delegates:
        #
        #   delegate:
        #     github: github-enterprise
        #     travis-ci:
        #       - travis-infrastructure
        #       - travis-pro
        #
        # In this case, the build scheduling looks at the travis-ci account to
        # determine the runnable jobs for the account travis-infrastructure and
        # travis-pro.
        #
        # The scheduler looks at all the running jobs for all accounts to
        # determine the number of runnable job.
        #
        class DelegationGrouping
          attr_reader :delegations

          # @param [Hash] Mapping of delegations, linking one owner to another owner, where the first owner is the main queue.
          def initialize(delegations)
            @delegations = setup_delegations(delegations)
          end

          # Groups jobs based on owner delegations. This allows multiple owners
          # jobs to be merged into one logical queue.
          #
          # @param  [Array] A list of jobs.
          # @return [Hash] A grouping of owner names and jobs.
          def group(jobs)
            # group jobs by owner id
          end

          def setup_delegations(delegations)
            processed = {}
            delegations.each do |key, value|
              main = find_owner(key)
              break if main.nil?
              others = Array(value).map { |login| find_owner(login) }
              processed[main] = others.compact
            end
            processed
          end

          def find_owner(login)
            owner = find_organization(login) || find_user(login)
            unless owner
              Travis.logger.warn "owner (#{login}) could not be found"
              nil
            else
              owner
            end
          end

          def find_user(login)
            id = User.where(login: login).pluck('id').first
            if id
              { owner_type: 'User', owner_id: id }
            else
              nil
            end
          end

          def find_organization(login)
            id = Organization.where(login: login).pluck('id').first
            if id
              { owner_type: 'Organization', owner_id: id }
            else
              nil
            end
          end
        end
      end
    end
  end
end
