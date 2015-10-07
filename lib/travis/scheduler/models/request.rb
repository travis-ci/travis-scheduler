require 'active_record'
require 'travis/scheduler/models/commit'
require 'travis/scheduler/models/organization'
require 'travis/scheduler/models/repository'
require 'travis/scheduler/models/user'

class Request < ActiveRecord::Base
  belongs_to :commit
  belongs_to :repository
  belongs_to :owner, polymorphic: true

  serialize :payload

  def pull_request?
    event_type == 'pull_request'
  end

  def pull_request_title
    payload && payload['pull_request'] && payload['pull_request']['title'] if pull_request?
  end

  # TODO duplicated in Commit
  def pull_request_number
    payload && payload['pull_request'] && payload['pull_request']['number'] if pull_request?
  end

  def branch_name
    payload && payload['ref'] && payload['ref'].scan(%r{refs/heads/(.*?)$}).flatten.first
  end

  def tag_name
    payload && payload['ref'] && payload['ref'].scan(%r{refs/tags/(.*?)$}).flatten.first
  end

  def same_repo_pull_request?
    payload = Hashr.new(self.payload)
    head_repo = payload.pull_request.try(:head).try(:repo).try(:full_name)
    base_repo = payload.pull_request.try(:base).try(:repo).try(:full_name)
    !!(head_repo && base_repo && head_repo == base_repo)
  rescue => e
    Travis::Scheduler.logger.error "[request:#{id}] Couldn't determine whether pull request is from the same repository: #{e.message}"
    false
  end
end
