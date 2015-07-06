require 'core_ext/hash/deep_symbolize_keys'
require 'active_record'
require 'travis/scheduler/models/request'

class Build < ActiveRecord::Base
  belongs_to :repository
  belongs_to :request
  belongs_to :commit
  belongs_to :owner, polymorphic: true

  delegate :same_repo_pull_request?, :to => :request

  def secure_env_enabled?
    !pull_request? || same_repo_pull_request?
  end
  alias addons_enabled? secure_env_enabled?

  def pull_request?
    event_type == 'pull_request'
  end
end
