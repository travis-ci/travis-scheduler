# frozen_string_literal: true

module Travis
  module Scheduler
    module Serialize
      class Worker
        class SshKey < Struct.new(:repo, :job, :config)
          def data
            if public? && !enterprise? && github?
              nil
            elsif settings_key
              { source: :repository_settings, value: settings_key.decrypt, encoded: false }
            elsif job_key
              { source: :travis_yaml, value: job_key, encoded: true }
            elsif repo_key
              { source: :default_repository_key, value: repo_key, public_key: repo.key.public_key, encoded: false }
            else
              nil
            end
          end

          def custom?
            data && data[:source] != :default_repository_key
          end

          private

          def public?
            !repo.private?
          end

          def github?
            repo.github?
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
            repo.key&.private_key
            puts "repo_private_key: #{repo.key.private_key}"
            puts "repo_key: #{repo.key.inspect}"
          end
        end
      end
    end
  end
end
