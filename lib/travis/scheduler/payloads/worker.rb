require 'travis/scheduler/support/features'

module Travis
  module Scheduler
    module Payloads
      class Worker
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
          data = {
            'type' => 'test',
            'vm_type' => vm_type,
            # TODO legacy. remove this once workers respond to a 'job' key
            'build' => job_data,
            'job' => job_data,
            'source' => build_data,
            'repository' => repository_data,
            'config' => job.decrypted_config,
            'queue' => job.queue,
            'ssh_key' => ssh_key,
            'env_vars' => env_vars,
            'timeouts' => timeouts,
          }

          if Support::Features.active?(:cache_settings, repository)
            if Travis.config.cache_settings && queue_settings = Travis.config.cache_settings.to_h.fetch(job.queue.to_sym, nil)
              data.merge!({ 'cache_settings' => queue_settings })
            end
          end

          data
        end

        def build_data
          {
            'id' => build.id,
            'number' => build.number,
            'event_type' => build.event_type
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
            'tag' => request.tag_name.present? ? request.tag_name : nil,
            'pull_request' => commit.pull_request? ? commit.pull_request_number : false,
            'state' => job.state.to_s,
            'secure_env_enabled' => secure_env?,
            'debug_options' => job.debug_options
          }
          data
        end

        def repository_data
          {
            'id' => repository.id,
            'slug' => repository.slug,
            'github_id' => repository.github_id,
            'source_url' => repository.source_url,
            'api_url' => repository.api_url,
            'last_build_id' => repository.last_build_id,
            'last_build_number' => repository.last_build_number,
            'last_build_started_at' => format_date(repository.last_build_started_at),
            'last_build_finished_at' => format_date(repository.last_build_finished_at),
            'last_build_duration' => repository.last_build_duration,
            'last_build_state' => repository.last_build_state.to_s,
            'description' => repository.description
          }
        end

        def vm_type
          Support::Features.active?(:premium_vms, repository) ? 'premium' : 'default'
        end

        def ssh_key
          if repository.public? && !Travis.config.enterprise
            nil
          elsif ssh_key = repository.settings.ssh_key
            { 'source' => 'repository_settings', 'value' => ssh_key.value.decrypt, 'encoded' => false }
          elsif ssh_key = job.ssh_key
            { 'source' => 'travis_yaml', 'value' => ssh_key, 'encoded' => true }
          else
            { 'source' => 'default_repository_key', 'value' => repository.key.private_key, 'encoded' => false }
          end
        end

        def env_vars
          vars = settings.env_vars
          vars = vars.public unless secure_env?

          vars.map do |var|
            {
              'name' => var.name,
              'value' => var.value.decrypt,
              'public' => var.public
            }
          end
        end

        def timeouts
          { 'hard_limit' => timeout(:hard_limit), 'log_silence' => timeout(:log_silence) }
        end

        def timeout(type)
          if timeout = settings.send(:"timeout_#{type}")
            timeout = Integer(timeout)
            timeout * 60 # worker handles timeouts in seconds
          end
        end

        def settings
          repository.settings
        end

        def format_date(date)
          date && date.strftime('%Y-%m-%dT%H:%M:%SZ')
        end

        def secure_env?
          return @secure_env if defined? @secure_env
          @secure_env = job.secure_env?
        end
      end
    end
  end
end
