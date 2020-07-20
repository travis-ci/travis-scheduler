module Travis
  module Scheduler
    module Jobs
      module Capacity
        class Plan < Base
          METERED_PLAN_LIMIT = 9_999_999

          def applicable?
            on_metered_plan? || owners.subscribed?
          end

          def report(status, job)
            super.merge(max: max)
          end

          def accept?(job)
            super if !on_metered_plan? || billing_allowance[allowance_key(job)]
          end

          private

            def max
              @max ||= on_metered_plan? ? METERED_PLAN_LIMIT : owners.paid_capacity
            end

            def allowance_key(job)
              job.public? ? 'public_repos' : 'private_repos'
            end
        end
      end
    end
  end
end
