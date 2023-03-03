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
            :managed_by_app?, :installation, :vcs_id, :vcs_type, :url, :vcs_source_host, :server_type

          def vm_type
            Features.active?(:premium_vms, repo) ? :premium : :default
          end

          def timeouts
            { hard_limit: hard_limit_timeout, log_silence: timeout(:log_silence) }
          end

          def api_url
            "#{config[:github][:api_url]}/repos/#{slug}"
          end

          def source_url
            return repo.vcs_source_host if travis_vcs_proxy?
            return repo.clone_url if repo.vcs_type == 'AssemblaRepository' && repo.server_type == 'perforce'
            return source_git_url if force_private? && !Travis.config.prefer_https
            return source_http_url if Travis.config.prefer_https || managed_by_app?
            (repo.private? || force_private?) ? source_git_url : source_http_url
          end

          def source_git_url(repo_slug = nil)
            "git@#{source_host}:#{repo_slug || slug}.git"
          end

          def source_http_url(repo_slug = nil)
            "https://#{source_host}/#{repo_slug || slug}.git"
          end

          def installation_id
            repo.installation&.github_id if repo.managed_by_app? && (repo.private || force_private?)
          end

          def keep_netrc?
            repo.owner&.keep_netrc?
          end

          def github?
            vcs_type == 'GithubRepository'
          end

          def travis_vcs_proxy?
            vcs_type == 'TravisproxyRepository'
          end

          def owner_type
            repo.owner_type
          end

          def owner_id
            repo.owner_id
          end

          private

            # If the repo does not have a custom timeout, look to the repo's
            #   owner for a default value, which might change depending on their
            #   current paid/unpaid status.
            #
            def hard_limit_timeout
              timeout(:hard_limit) || repo.owner.default_worker_timeout
            end

            def timeout(type)
              return unless timeout = repo.settings.send(:"timeout_#{type}")
              timeout = Integer(timeout)
              timeout * 60 # worker handles timeouts in seconds
            end

            def force_private?
              return repo.vcs_source_host != source_host if repo.vcs_source_host

              github? && source_host != 'github.com'
            end

            def source_host
              return URI(URI::Parser.new.escape repo.vcs_source_host)&.host if travis_vcs_proxy?
              repo.vcs_source_host || config[:github][:source_host] || 'github.com'
            rescue Exception => e
              puts "source host fail: #{e.message}"
              repo.vcs_source_host || config[:github][:source_host] || 'github.com'
            end
        end
      end
    end
  end
end
