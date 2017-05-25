require 'forwardable'
require 'travis/scheduler/serialize/worker/config'

module Travis
  module Scheduler
    module Serialize
      class Worker
        class Job < Struct.new(:job)
          extend Forwardable

          def_delegators :job, :id, :repository, :source, :config, :commit,
            :number, :queue, :state, :debug_options, :queued_at, :allow_failure
          def_delegators :source, :request

          def env_vars
            vars = repository.settings.env_vars
            vars = vars.public unless secure_env?
            vars.map { |var| env_var(var) }
          end

          def secure_env?
            defined?(@secure_env) ? @secure_env : @secure_env = !pull_request? || same_repo_pull_request?
          end

          def pull_request?
            source.event_type == 'pull_request'
          end

          def same_repo_pull_request?
            request.same_repo_pull_request?
          end

          def secure_env_removed?
            !secure_env? &&
            (job.repository.settings.has_secure_vars? || has_secure_vars?(:env) || has_secure_vars?(:global_env))
          end

          def ssh_key
            config[:source_key]
          end

          def decrypted_config
            secure = Travis::SecureConfig.new(repository.key)
            Config.decrypt(config, secure, full_addons: secure_env?, secure_env: secure_env?)
          end

          private

            def env_var(var)
              { name: var.name, value: var.value.decrypt, public: var.public }
            end

            def has_secure_vars?(key)
              config.key?(key) &&
              config[key].respond_to?(:key?) &&
              config[key].key?(:secure)
            end
        end
      end
    end
  end
end
