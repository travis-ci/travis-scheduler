require 'travis/scheduler/helper/context'
require 'travis/scheduler/helper/metrics'
require 'travis/support/filter_migrated_jobs'

module Travis
  module Scheduler
    module Jobs
      class State < Struct.new(:context, :owners)
        include Helper::Metrics
        include Helper::Context
        include FilterMigratedJobs

        ATTRS = {
          running: %i[repository_id private queue org_id restarted_at],
          by_build: %i[id state stage_number]
        }

        def running
          @running ||= read_running
        end

        def queueable
          @queueable ||= read_queueable
        end

        def by_build(id)
          cache[id] ||= Job.where(source_id: id).select(*ATTRS[:by_build]).to_a
        end

        def count_queueable
          queueable.size
        end

        def count_running
          counts[:all] ||= running.size
        end

        def count_running_by_repo(id)
          counts[:repo][id] ||= running.select { |job| job.repository_id == id }.size
        end

        def count_running_by_queue(name)
          counts[:queue][name] ||= running.select { |job| job.queue == name }.size
        end

        private

        def read_running
          result = Job.by_owners(owners.all).running.select(*ATTRS[:running]).includes(:repository).to_a
          filter_migrated_jobs(result)
        end
        time :read_queueable, key: 'scheduler.running_jobs'

        def read_queueable
          filter_migrated_jobs(Job.by_owners(owners.all).queueable.to_a)
        end
        time :read_queueable, key: 'scheduler.queueable_jobs'

        def cache
          @cache ||= {}
        end

        def counts
          @counts ||= { repo: {}, queue: {} }
        end
      end
    end
  end
end
