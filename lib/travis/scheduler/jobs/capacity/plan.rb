# frozen_string_literal: true

module Travis
  module Scheduler
    module Jobs
      module Capacity
        class Plan < Base
          def applicable?
            on_metered_plan? || owners.subscribed?
          end

          def report(status, job)
            super.merge(max:)
          end

          def accept?(job)
            super if !on_metered_plan? || billing_allowed?(job)
          end

          private

          def max
            @max ||= on_metered_plan? ? billing_allowance['concurrency_limit'] : owners.paid_capacity
          end

          def billing_allowed?(job)
            puts billing_allowance[allowance_key(job)]
            return true if billing_allowance[allowance_key(job)]

            # Cancel job if it has not been queued for more than a day due to
            # billing allowance
            if job.created_at < (Time.now - 1.day)
              payload = { id: job.id, source: 'scheduler' }
              Hub.push('job:cancel', payload)
            end

            false
          end

          def allowance_key(job)
            job.public? ? 'public_repos' : 'private_repos'
          end
        end
      end
    end
  end
end
