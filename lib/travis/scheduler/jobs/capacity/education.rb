require 'travis/scheduler/helper/memoize'

module Travis
  module Scheduler
    module Jobs
      module Capacity
        class Education < Base
          include Helper::Memoize

          def applicable?
            educational?
          end

          def accept?(job)
            super if educational?
          end

          def report(status, job)
            super.merge(max: max)
          end

          private

            def max
              @max ||= config[:limit][:educational] || 0
            end

            def educational?
              owners.educational?
            end
            memoize :educational?
        end
      end
    end
  end
end
