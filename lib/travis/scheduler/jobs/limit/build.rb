require 'travis/scheduler/helper/condition'

module Travis
  module Scheduler
    module Jobs
      module Limit
        class Build < Base
          def accept?(job)
            return true unless applies?(job) && max(job)
            super
          end

          private

            def max(job)
              return unless applies?(job)
              num = job.repository.settings.maximum_number_of_builds
              num > 0 ? num : nil
            end

            def applies?(job)
              # remove this once the setting for concurrent jobs has been renamed
              return unless cond = condition(job)
              Condition.new(cond, job).applies?
            end

            def condition(job)
              job.repository.settings.maximum_number_of_builds_condition
            end

            def running(job)
              state.running.select(&method(:applies?)).size
            end

            def report(status, job)
              {
                type: :limit,
                name: :build,
                status: status,
                repo_slug: job.repository.slug,
                id: job.id,
                max: max(job)
              }
            end
        end
      end
    end
  end
end
