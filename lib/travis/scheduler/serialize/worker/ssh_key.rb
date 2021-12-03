module Travis
  module Scheduler
    module Serialize
      class Worker
        class SshKey < Struct.new(:repo, :job, :config, :skip_settings_key)
          def data
            if public? && !enterprise?
              nil
            elsif settings_key && !skip_settings_key
              { source: :repository_settings, value: settings_key.decrypt, encoded: false }
            elsif job_key
              { source: :travis_yaml, value: job_key, encoded: true }
            else
              { source: :default_repository_key, value: repo_key, encoded: false }
            end
          end

          private

            def public?
              !repo.private?
            end

            def enterprise?
              config[:enterprise]
            end

            def settings_key
              repo.settings.ssh_key && repo.settings.ssh_key.value
            end

            def job_key
              job.ssh_key
            end

            def repo_key
              repo.key.private_key
            end

        end
      end
    end
  end
end
