require 'travis/scheduler/helper/context'
require 'travis/scheduler/helper/metrics'

module Travis
  module Scheduler
    module Jobs
      class State < Struct.new(:context, :owners)
        include Helper::Context, Helper::Metrics

        ATTRS = {
          running:  %i(repository_id private queue org_id restarted_at),
          by_build: %i(id state stage_number)
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
            collection = Job.by_owners(owners.all).running.select(*ATTRS[:running]).includes(:repository).to_a
            if Travis.config.com?
              collection = collection.find_all { |job|
                # I think it's fine to filter running jobs after querying. usually
                # it's not a good idea to do it in Ruby rather than SQL but jobs
                # that might be rejected here will be rather rare - it's only for
                # the purpose of not running migrated jobs. Doing it in SQL on the
                # other hand would likely need an additional index and a join with
                # repositories
                #
                !job.org_id || (job.restarted_at && job.restarted_at > job.repository.migrated_at)
              }
            end
            collection
          end
          time :read_queueable, key: 'scheduler.running_jobs'

          def read_queueable
            Job.by_owners(owners.all).queueable.to_a
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
