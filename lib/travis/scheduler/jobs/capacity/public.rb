# frozen_string_literal: true

module Travis
  module Scheduler
    module Jobs
      module Capacity
        class Public < Base
          def applicable?
            !on_metered_plan?
          end

          def reduce(jobs)
            rest = super(jobs.select(&:public?))
            rest + jobs.select(&:private?)
          end

          def accept?(job)
            super if job.public?
          end

          def report(status, job)
            super.merge(repo_slug: job.repository.slug, max:)
          end

          private

          def max
            config[:limit][:public]
          end
        end
      end
    end
  end
end
