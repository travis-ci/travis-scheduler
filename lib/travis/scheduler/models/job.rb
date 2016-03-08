require 'active_record'
require 'travis/scheduler/models/build'
require 'travis/scheduler/models/commit'
require 'travis/scheduler/models/log'
require 'travis/scheduler/models/organization'
require 'travis/scheduler/models/repository'
require 'travis/scheduler/models/user'

class Job < ActiveRecord::Base
  require 'travis/scheduler/models/job/config'

  class Test < Job; end

  class << self
    # what needs to be queued up
    def queueable(queue = nil)
      scope = where(state: :created).order('jobs.id')
      scope = scope.where(queue: queue) if queue
      scope
    end

    # what already is queued or started
    def running(queue = nil)
      scope = where(state: [:queued, :received, :started]).order('jobs.id')
      scope = scope.where(queue: queue) if queue
      scope
    end

    def owned_by(owner)
      where(owner_id: owner.id, owner_type: owner.class.to_s)
    end
  end

  belongs_to :repository
  belongs_to :commit
  belongs_to :source, polymorphic: true, autosave: true
  belongs_to :owner, polymorphic: true

  serialize :config
  serialize :debug_options
  delegate :secure_env?, :full_addons?, to: :source

  def ssh_key
    config[:source_key]
  end

  def decrypted_config
    options = { full_addons: full_addons?, secure_env: secure_env? }
    Config.decrypt(config, repository.key.secure, options)
  end
end
