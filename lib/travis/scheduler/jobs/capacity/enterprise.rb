module Travis
  module Scheduler
    module Jobs
      module Capacity
        class Enterprise < Base
          def applicable?
            config[:enterprise]
          end

          def accept?(job)
            accept(job) if config[:enterprise]
          end

          def report(status, job)
            super.merge(repo_slug: job.repository.slug, max: max)
          end

          private

          def max
            99999
          end

        end
      end
    end
  end
end
