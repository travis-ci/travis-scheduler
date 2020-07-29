require 'travis/scheduler/model/boost'

module Travis
  module Scheduler
    module Jobs
      module Capacity
        class Boost < Base
          def applicable?
            !on_metered_plan? && boost.exists?
          end

          def report(status, job)
            super.merge(max: max)
          end

          private

            def max
              @max ||= boost.max
            end

            def boost
              @boost ||= Model::Boost.new(owners, context.redis)
            end
        end
      end
    end
  end
end
