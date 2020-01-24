require 'active_record'
require 'travis/scheduler/record/organization'
require 'travis/scheduler/record/repository'
require 'travis/scheduler/record/user'
require 'gh'

class Request < ActiveRecord::Base
  belongs_to :commit
  belongs_to :pull_request
  belongs_to :repository
  belongs_to :owner, polymorphic: true

  serialize :payload

  # This check has been put in place in order to address a security issue on
  # GitHub's side. See https://blog.travis-ci.com/2016-07-07-security-advisory-encrypted-variables.
  #
  # The underlying issue has been fixed by GitHub in June 2016 (see
  # https://github.com/travis-pro/team-teal/issues/1280#issuecomment-250129327),
  # but we're keeping this check around for the time being, especially for
  # Enterprise.
  def same_repo_pull_request?
    # When we're starting to archive payloads after N months we'll also disallow
    # restarting builds older than N months. Once we do so we can also return
    # false if Scheduler.config.enterprise is not true.

    # It's not the same repo PR if repo names don't match
    return false if head_repo_vcs_id.to_s != repository.vcs_id.to_s
    # It may not be the same repo if head_ref or head_sha are missing
    return false if head_ref.nil? or head_sha.nil?
    # It may not be same repo PR if ref is a commit
    return false if head_sha =~ /^#{Regexp.escape(head_ref)}/
    true
  rescue => e
    Travis::Scheduler.logger.error "[request:#{id}] Couldn't determine whether pull request is from the same repository: #{e.message}"
    false
  end

  def payload
    fail "[deprectated] Reading request.payload."
  end

  private

    def head_repo_vcs_id
      pull_request&.head_repo_vcs_id
    end

    def head_ref
      pull_request&.head_ref
    end

    def head_sha
      head_commit
    end
end
