module Travis
  module Scheduler
    module Jobs
      class State < Struct.new(:context, :owners)
        ATTRS = {
          running:  %i(repository_id private queue),
          by_build: %i(id state stage_number)
        }

        # this reads all of the owners' currently running jobs into memory.
        # is this preferable? should we run several db queries instead?
        def running
          @running ||= Job.by_owners(owners.all).running.select(*ATTRS[:running]).to_a
        end

        def queueable
          @queueable ||= Job.by_owners(owners.all).queueable.to_a
        end
        # time :queueable, key: 'scheduler.queueable_jobs'

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
