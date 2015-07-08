require 'travis/scheduler/models/job'

module Travis
  module Scheduler
    module Services
      module Limit
        class Default
          attr_reader :owner, :jobs, :config

          def initialize(owner, jobs)
            @owner = owner
            @jobs  = jobs
            @config = Travis.config.limit || {}
          end

          def queueable
            @queueable ||= filter_by_repository(jobs)[0, max_queueable]
          end

          def filter_by_repository(jobs)
            queueable_by_repository_id = {}
            jobs.reject do |job|
              if job.repository.settings.maximum_number_of_builds.to_i > 0
                queueable?(job, queueable_by_repository_id, running_by_repository_id)
              end
            end
          end

          def running_by_repository_id
            @running_by_repository ||= Hash[repository_id_grouping]
          end

          def repository_id_grouping
            running_jobs.group_by(&:repository_id).map do |repository_id, jobs|
              [repository_id, jobs.size]
            end
          end

          def queueable?(job, queueable, running)
            repository = job.repository_id
            queueable[repository] ||= 0

            runnable_count = queueable[repository] + (running[repository] || 0)
            if runnable_count < job.repository.settings.maximum_number_of_builds
              queueable[repository] += 1
              false
            else
              true
            end
          end

          def report
            { total: jobs.size, running: running, max: max_jobs, queueable: queueable.size }
          end

          private

            def running_jobs
              @running_jobs ||= Job.owned_by(owner).running
            end

            def running
              @running ||= running_jobs.to_a.size
            end

            def max_queueable
              puts "max_queueable: owner.login=#{owner.login.inspect}"
              return config[:default] if owner.login.nil?

              if unlimited?
                999
              else
                queueable = max_jobs - running
                queueable < 0 ? 0 : queueable
              end
            end

            def max_jobs
              puts "max_queueable: config[:by_owner]=#{config[:by_owner].inspect}"
              puts "max_queueable: config[:by_owner][owner.login]=#{config[:by_owner][owner.login].inspect}"
              config[:by_owner][owner.login] || config[:default]
            end

            def unlimited?
              config[:by_owner][owner.login] == -1
            end
        end
      end
    end
  end
end
