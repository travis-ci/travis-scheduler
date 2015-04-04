module Travis
  module Enqueue
    module Services
      module Helpers
        class WorkerPayload
          include Formats

          attr_reader :job

          def initialize(job, options = {})
            @job = job
          end

          def commit
            job.commit
          end

          def repository
            job.repository
          end

          def request
            build.request
          end

          def build
            job.source
          end

          def data
            {
              'type' => 'test',
              'job' => job_data,
              'source' => build_data,
              'repository' => repository_data,
              'config' => job.decrypted_config,
              'queue' => job.queue,
              'uuid' => Travis.uuid,
              'ssh_key' => ssh_key,
              'env_vars' => env_vars,
              'timeouts' => timeouts
            }
          end

          def build_data
            {
              'id' => build.id,
              'number' => build.number
            }
          end

          def job_data
            data = {
              'id' => job.id,
              'number' => job.number,
              'commit' => commit.commit,
              'commit_range' => commit.range,
              'commit_message' => commit.message,
              'branch' => commit.branch,
              'ref' => commit.pull_request? ? commit.ref : nil,
              'state' => job.state.to_s,
              'secure_env_enabled' => job.secure_env_enabled?
            }
            data['tag'] = request.tag_name if include_tag_name?
            data['pull_request'] = commit.pull_request? ? commit.pull_request_number : false
            data
          end

          def repository_data
            {
              'id' => repository.id,
              'slug' => repository.slug,
              'github_id' => repository.github_id,
              'source_url' => repository.source_url,
              'api_url' => repository.api_url,
              'description' => repository.description
            }
          end

          def ssh_key
            nil
          end

          def env_vars
            vars = settings.env_vars
            vars = vars.public unless job.secure_env_enabled?

            vars.map do |var|
              {
                'name' => var.name,
                'value' => var.value.decrypt,
                'public' => var.public
              }
            end
          end

          def timeouts
            {
              'hard_limit': timeout(:hard_limit),
              'log_silence': timeout(:log_silence)
            }
          end

          def timeout(type)
            timeout = settings.send(:"timeout_#{type}")
            # worker handles timeouts in seconds
            timeout = timeout * 60 if timeout 
            timeout
          end

          def include_tag_name?
            Travis.config.include_tag_name_in_worker_payload && request.tag_name.present?
          end

          def settings
            repository.settings
          end
        end
      end
    end
  end
end