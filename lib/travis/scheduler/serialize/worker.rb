# frozen_string_literal: true

module Travis
  module Scheduler
    module Serialize
      class Worker < Struct.new(:job, :config)
        require 'travis/scheduler/serialize/worker/build'
        require 'travis/scheduler/serialize/worker/commit'
        require 'travis/scheduler/serialize/worker/config'
        require 'travis/scheduler/serialize/worker/job'
        require 'travis/scheduler/serialize/worker/request'
        require 'travis/scheduler/serialize/worker/repo'
        require 'travis/scheduler/serialize/worker/ssh_key'
        require 'travis/scheduler/vcs_proxy'

        def data
          data = {
            type: :test,
            vm_config: job.vm_config,
            vm_type: repo.vm_type,
            vm_size: job.vm_size,
            queue: job.queue,
            config: job.decrypted_config,
            env_vars: env_vars_with_custom_keys,
            job: job_data,
            host: Travis::Scheduler.config.host,
            source: build_data,
            repository: repository_data,
            ssh_key: ssh_key&.data || nil,
            timeouts: repo.timeouts,
            cache_settings:,
            workspace:,
            enterprise: !!config[:enterprise],
            prefer_https: !!config[:prefer_https],
            keep_netrc: repo.keep_netrc?,
            secrets: job.secrets,
            allowed_repositories:
          }
          data[:trace]  = true if job.trace?
          data[:warmer] = true if job.warmer?
          data[:oauth_token] = github_oauth_token if config[:prefer_https]

          if travis_vcs_proxy?
            creds = build_credentials
            data[:build_token] = (creds['token'] if creds) || ''
            data[:sender_login] = (creds['username'] if creds) || ''
          end

          data
        rescue Exception => e
          puts "ex: #{e.message}"
        end

        private

        def build_data
          {
            id: build.id,
            number: build.number,
            event_type: build.event_type
          }
        end

        def job_data
          data = {
            id: job.id,
            number: job.number,
            commit: commit.commit,
            commit_range: commit.range,
            commit_message: commit.message,
            branch: commit.branch,
            ref: commit.pull_request? ? commit.ref : nil,
            tag: commit.tag,
            pull_request: build.pull_request? ? build.pull_request_number : false,
            state: job.state.to_s,
            secure_env_enabled: job.secure_env?,
            secure_env_removed: job.secure_env_removed?,
            debug_options: job.debug_options || {},
            queued_at: format_date(job.queued_at),
            allow_failure: job.allow_failure,
            stage_name: job.stage&.name,
            name: job.name,
            restarted: job.restarted_at.present?,
            restarted_by: job.restarted_by
            #default value is null,
            #if job restarted it must contain the login of the user triggering the restart
            #(either via UI or based on authentication token if restarted directly via API / travis-cli)
          }
          if build.pull_request?
            data = data.merge(
              pull_request_head_branch: request.pull_request_head_ref,
              pull_request_head_sha: request.pull_request_head_sha,
              pull_request_head_slug: request.pull_request_head_slug,
              pull_request_base_slug: request.pull_request_base_slug,
              pull_request_base_ref: request.pull_request_base_ref,
              pull_request_head_url: request.pull_request_head_url(repo),
              pull_request_is_draft: request.pull_request_is_draft?
            )
          end
          data
        end

        def repository_data
          compact(
            id: repo.id,
            github_id: repo.github_id,
            vcs_id: repo.vcs_id,
            vcs_type: repo.vcs_type,
            url: repo.url,
            installation_id: repo.installation_id,
            private: repo.private?,
            slug: repo.slug,
            source_url:,
            source_host:,
            api_url: repo.api_url,
            # TODO: how come the worker needs all these?
            last_build_id: repo.last_build_id,
            last_build_number: repo.last_build_number,
            last_build_started_at: format_date(repo.last_build_started_at),
            last_build_finished_at: format_date(repo.last_build_finished_at),
            last_build_duration: repo.last_build_duration,
            last_build_state: repo.last_build_state.to_s,
            default_branch: repo.default_branch,
            description: repo.description,
            server_type: repo.server_type || 'git'
          )
        end

        def source_url
          # TODO: move these things to Build
          return repo.source_git_url if repo.private? && ssh_key&.custom? && !travis_vcs_proxy?

          repo.source_url
        end

        def job
          @job ||= Job.new(super, config)
        end

        def repo
          @repo ||= Repo.new(job.repository, config)
        end

        def request
          @request ||= Request.new(build.request)
        end

        def commit
          @commit ||= Commit.new(job.commit)
        end

        def build
          @build ||= Build.new(job.source)
        end

        def selected_repo
          @selected_repo ||= ssh_key_repository
        end

        def ssh_key
          return nil unless selected_repo

          @ssh_key ||= SshKey.new(Repo.new(selected_repo, config), job, config)
        end

        def ssh_key_repository
          return job.repository if job.source.event_type != 'pull_request' || job.source.request.pull_request.head_repo_slug == job.source.request.pull_request.base_repo_slug

          base_repo_owner_name, base_repo_name = job.source.request.pull_request.base_repo_slug.to_s.split('/')
          return job.repository if base_repo_owner_name.nil? || base_repo_owner_name.empty? || base_repo_name.nil? || base_repo_name.empty?

          base_repo = ::Repository.find_by(owner_name: base_repo_owner_name, name: base_repo_name)
          return job.repository if base_repo.nil? || !base_repo.private
          return base_repo if base_repo.settings.share_ssh_keys_with_forks?

          head_repo_owner_name, head_repo_name = job.source.request.pull_request.head_repo_slug.to_s.split('/')
          return job.repository if head_repo_owner_name.nil? || head_repo_owner_name.empty? || head_repo_name.nil? || head_repo_name.empty?

          ::Repository.find_by(owner_name: head_repo_owner_name, name: head_repo_name) || nil
        end

        def source_host
          return URI(URI::Parser.new.escape(repo.vcs_source_host))&.host if travis_vcs_proxy?

          repo.vcs_source_host || config[:github][:source_host] || 'github.com'
        rescue Exception => e
          repo.vcs_source_host || config[:github][:source_host] || 'github.com'
        end

        def cache_settings
          if cache_config[job.queue]
            cache_config[job.queue].to_h
          elsif cache_config['default']
            cache_config['default'].to_h
          end
        end

        def cache_config
          config[:cache_settings] || {}
        end

        def workspace
          if (ws_config = config[:workspace] || {}) && ws_config[job.queue]
            config[:workspace][job.queue].to_h
          elsif (ws_config = config[:workspace] || {}) && ws_config['default']
            config[:workspace]['default'].to_h
          end
        end

        def format_date(date)
          date && date.strftime('%Y-%m-%dT%H:%M:%SZ')
        end

        def github_oauth_token
          scope = job.repository.users
          scope = scope.where('github_oauth_token IS NOT NULL').order('updated_at DESC')
          admin = scope.first
          admin && admin.github_oauth_token
        end

        def compact(hash)
          hash.reject { |_, value| value.nil? }
        end

        def sender_token
          @user ||= User.where(id: build.sender_id)&.first
          @user.github_oauth_token if @user
        end

        def build_credentials
          Travis::Scheduler::VcsProxy.new(config, sender_token).credentials(repo)
        end

        def sender_login
          @user ||= User.where(id: build.sender_id)&.first
          @user.login if @user
        end

        def allowed_repositories
          @allowed_repositories ||= begin
            repository_ids = Repository.where(owner_id: build.owner_id, active: true).select { |repo| repo.settings.allow_config_imports }.map(&:vcs_id)
            repository_ids << repo.vcs_id
            repository_ids.uniq.sort
          end
        end

        def travis_vcs_proxy?
          repo.vcs_type == 'TravisproxyRepository'
        end

        def env_vars_with_custom_keys
          job.env_vars + custom_keys
        end

        def custom_keys
          return [] if job.decrypted_config[:keys].blank?

          if job.source.event_type == 'pull_request' && job.source.request.pull_request.head_repo_slug != job.source.request.pull_request.base_repo_slug
            base_repo_owner_name, base_repo_name = job.source.request.pull_request.base_repo_slug.to_s.split('/')
            return [] unless base_repo_owner_name && base_repo_name

            base_repo = ::Repository.find_by(owner_name: base_repo_owner_name, name: base_repo_name)
            return [] unless base_repo && base_repo.settings.share_ssh_keys_with_forks?

          end

          job.decrypted_config[:keys].map do |key|
            custom_key = CustomKey.where(name: key, owner_id: build.sender_id, owner_type: 'User').first
            if custom_key.nil?
              org_ids = Membership.where(user_id: build.sender_id).map(&:organization_id)
              if !base_repo.nil? && base_repo.owner_type == 'Organization'
                org_ids.reject! { |id| id != base_repo.owner_id }
              elsif repo.owner_type == 'Organization'
                org_ids.reject! { |id| id != repo.owner_id }
              end

              custom_key = CustomKey.where(name: key, owner_id: org_ids, owner_type: 'Organization').first unless org_ids.empty?
            end
            custom_key.nil? ? nil : { name: "TRAVIS_#{key}", value: Base64.strict_encode64(custom_key.private_key), public: false, branch: nil }
          end.compact
        end
      end
    end
  end
end
