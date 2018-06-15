module Travis
  module Scheduler
    module Jobs
      module Capacity
        class Plan < Base
          def report(status, job)
            super.merge(max: max)
          end

          private

            def max
              @max ||= owners.paid_capacity
            end
        end
      end
    end
  end
end
