require 'forwardable'
require 'travis/scheduler/serialize/worker/config'

module Travis
  module Scheduler
    module Serialize
      class Worker
        class Job < Struct.new(:job, :config)
          extend Forwardable

          def_delegators :job, :id, :repository, :source, :commit, :number,
            :queue, :state, :debug_options, :queued_at, :allow_failure, :stage
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
            job.config[:source_key]
          end

          def decrypted_config
            secure = Travis::SecureConfig.new(repository.key)
            Config.decrypt(job.config, secure, full_addons: secure_env?, secure_env: secure_env?)
          end

          def vm_config
            # we'll want to see out what kinds of vm_config sets we have and
            # then decide how to best map what to where. at this point that
            # decision is yagni though, so i'm just picking :gpu as a key here.
            vm_config? && vm_configs[:gpu] ? vm_configs[:gpu].to_h : {}
          end

          def trace?
            Rollout.matches?(:trace, uid: SecureRandom.hex, owner: repository.owner.login, repo: repository.slug, redis: Scheduler.redis)
          end

          def warmer?
            Rollout.matches?(:warmer, uid: SecureRandom.hex, owner: repository.owner.login, repo: repository.slug, redis: Scheduler.redis)
          end

          private

            def env_var(var)
              { name: var.name, value: var.value.decrypt, public: var.public }
            end

            def has_secure_vars?(key)
              job.config.key?(key) &&
                job.config[key].respond_to?(:key?) &&
                job.config[key].key?(:secure)
            end

            def vm_config?
              Features.active?(:resources_gpu, repository) && job.config.dig(:resources, :gpu)
            end

            def vm_configs
              config[:vm_configs] || {}
            end
        end
      end
    end
  end
end
