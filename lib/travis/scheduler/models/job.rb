require 'active_record'
require 'active_support/core_ext/hash/deep_dup'
require 'travis/scheduler/models/build'
require 'travis/scheduler/models/commit'
require 'travis/scheduler/models/organization'
require 'travis/scheduler/models/repository'
require 'travis/scheduler/models/user'

class Job < ActiveRecord::Base
  class Test < Job; end

  WHITELISTED_ADDONS = %w(
    apt
    apt_packages
    apt_sources
    firefox
    hosts
    postgresql
    ssh_known_hosts
  ).freeze

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
  delegate :secure_env_enabled?, :addons_enabled?, to: :source

  def ssh_key
    config[:source_key]
  end

  def decrypted_config
    normalize_config(self.config).deep_dup.tap do |config|
      config[:env] = process_env(config[:env]) { |env| decrypt_env(env) } if config[:env]
      config[:global_env] = process_env(config[:global_env]) { |env| decrypt_env(env) } if config[:global_env]
      if config[:addons]
        if addons_enabled?
          config[:addons] = decrypt_addons(config[:addons])
        else
          delete_addons(config)
        end
      end
    end
  rescue => e
    logger.warn "[job id:#{id}] Config could not be decrypted due to #{e.message}"
    {}
  end

  private

    def normalize_config(config)
      config = config ? config.deep_symbolize_keys : {}

      if config[:deploy]
        config[:addons] ||= {}
        config[:addons][:deploy] = config.delete(:deploy)
      end

      config
    end

    def process_env(env)
      env = [env] unless env.is_a?(Array)
      env = normalize_env(env)
      env = if secure_env_enabled?
        yield(env)
      else
        remove_encrypted_env_vars(env)
      end
      env.compact.presence
    end

    def remove_encrypted_env_vars(env)
      env.reject do |var|
        var.is_a?(Hash) && var.has_key?(:secure)
      end
    end

    def normalize_env(env)
      env.map do |line|
        if line.is_a?(Hash) && !line.has_key?(:secure)
          line.map { |k, v| "#{k}=#{v}" }.join(' ')
        else
          line
        end
      end
    end

    def delete_addons(config)
      if config[:addons].is_a?(Hash)
        config[:addons].keep_if { |key, _| WHITELISTED_ADDONS.include? key.to_s }
      else
        config.delete(:addons)
      end
    end

    def decrypt_addons(addons)
      decrypt(addons)
    end

    def decrypt_env(env)
      env.map do |var|
        decrypt(var) do |var|
          var.dup.insert(0, 'SECURE ') unless var.include?('SECURE ')
        end
      end
    rescue
      {}
    end

    def decrypt(v, &block)
      repository.key.secure.decrypt(v, &block)
    end
end
