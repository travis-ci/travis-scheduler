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
        require 'travis/scheduler/helper/job_repository'

        include Travis::Scheduler::Helper::JobRepository

        def data
          value = {
            type: :test,
            vm_type: repo.vm_type,
            queue: job.queue,
            config: job.decrypted_config,
            env_vars: job.env_vars,
            job: job_data,
            source: build_data,
            repository: repository_data,
            ssh_key: ssh_key,
            timeouts: repo.timeouts,
            cache_settings: cache_settings,
          }
          value[:oauth_token] = github_oauth_token if Travis.config.prefer_https?
          value
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
            }
            if build.pull_request?
              data = data.merge(
                pull_request_head_branch: request.pull_request_head_ref,
                pull_request_head_sha: request.pull_request_head_sha,
                pull_request_head_slug: request.pull_request_head_slug,
              )
            end
            data
          end

          def repository_data
            {
              id: repo.id,
              github_id: repo.github_id,
              slug: repo.slug,
              source_url: repo.source_url,
              api_url: repo.api_url,
              # TODO how come the worker needs all these?
              last_build_id: repo.last_build_id,
              last_build_number: repo.last_build_number,
              last_build_started_at: format_date(repo.last_build_started_at),
              last_build_finished_at: format_date(repo.last_build_finished_at),
              last_build_duration: repo.last_build_duration,
              last_build_state: repo.last_build_state.to_s,
              default_branch: repo.default_branch,
              description: repo.description
            }
          end

          def job
            @job ||= Job.new(super)
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

          def ssh_key
            SshKey.new(Repo.new(job_repository, config),  job, config).data
          end

          def ssh_key_repository
            return job.repository if job.source.event_type != 'pull_request' || job.source.request.pull_request.head_repo_slug == job.source.request.pull_request.base_repo_slug

            pr_repository = ::Repository.find_by(github_id: job.source.pull_request.head_repo_github_id);
            return nil unless pr_repository

            base_repo_owner_name, base_repo_name = job.source.request.pull_request.base_repo_slug.to_s.split('/')
            return pr_repository if base_repo_owner_name.nil? || base_repo_owner_name.empty? || base_repo_name.nil? || base_repo_name.empty?
            base_repo = ::Repository.find_by(owner_name: base_repo_owner_name, name: base_repo_name)
            return pr_repository if base_repo.nil? || !base_repo.private
            return base_repo if base_repo.settings.share_ssh_keys_with_forks

            head_repo_owner_name, head_repo_name = job.source.request.pull_request.head_repo_slug.to_s.split('/')
            return pr_repository if head_repo_owner_name.nil? || head_repo_owner_name.empty? || head_repo_name.nil? || head_repo_name.empty?

            ::Repository.find_by(owner_name: head_repo_owner_name, name: head_repo_name) || pr_repository
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

          def format_date(date)
            date && date.strftime('%Y-%m-%dT%H:%M:%SZ')
          end

          def github_oauth_token
            candidates = job.repository.users.where("github_oauth_token IS NOT NULL").
                    order("updated_at DESC")
            admin = candidates.first
            admin && admin.github_oauth_token
          end
      end
    end
  end
end
