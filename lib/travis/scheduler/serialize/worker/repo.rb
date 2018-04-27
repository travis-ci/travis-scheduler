require 'forwardable'

module Travis
  module Scheduler
    module Serialize
      class Worker
        class Repo < Struct.new(:repo, :config)
          extend Forwardable

          def_delegators :repo, :id, :github_id, :slug,
            :last_build_id, :last_build_number, :last_build_started_at,
            :last_build_finished_at, :last_build_duration, :last_build_state,
            :default_branch, :description, :key, :settings, :private?,
            :managed_by_app?, :installation

          def vm_type
            Features.active?(:premium_vms, repo) ? :premium : :default
          end

          def timeouts
            { hard_limit: worker_timeout, log_silence: timeout(:log_silence) }
          end

          def api_url
            "#{config[:github][:api_url]}/repos/#{slug}"
          end

          def source_url
            return source_http_url if Travis.config.prefer_https || managed_by_app?
            (repo.private? || force_private?) ? source_git_url : source_http_url
          end

          def installation_id
            repo.installation&.github_id if repo.managed_by_app? && repo.private
          end

          private

            # If the repo does not have a custom timeout, look to the repo's
            #   owner for a default value, which might change depending on their
            #   current paid/unpaid status.
            #
            def worker_timeout
              timeout(:hard_limit) || repo.owner.default_worker_timeout
            end

            def env_var(var)
              { name: var.name, value: var.value.decrypt, public: var.public }
            end

            def timeout(type)
              return unless timeout = repo.settings.send(:"timeout_#{type}")

              timeout = Integer(timeout)
              timeout * 60 # worker handles timeouts in seconds
            end

            def force_private?
              source_host != 'github.com'
            end

            def source_http_url
              "https://#{source_host}/#{slug}.git"
            end

            def source_git_url
              "git@#{source_host}:#{slug}.git"
            end

            def source_host
              config[:github][:source_host] || 'github.com'
            end
        end
      end
    end
  end
end
