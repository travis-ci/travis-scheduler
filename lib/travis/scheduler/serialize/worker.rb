require 'date'

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

        def data
          {
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
              debug_options: job.debug_options || {},
              queued_at: DateTime.parse(job.queued_at).iso8601,
            }
            if build.pull_request?
              data = data.merge(
                pull_request_head_branch: request.pull_request_head_branch,
                pull_request_head_sha: request.pull_request_head_sha,
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
            SshKey.new(repo, job, config).data
          end

          def cache_settings
            cache_config[job.queue].to_h if cache_config[job.queue]
          end

          def cache_config
            config[:cache_settings] || {}
          end

          def format_date(date)
            date && date.strftime('%Y-%m-%dT%H:%M:%SZ')
          end
      end
    end
  end
end
