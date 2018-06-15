require 'travis/scheduler/model/boost'

module Travis
  module Scheduler
    module Jobs
      module Capacity
        class Boost < Base
          def report(status, job)
            super.merge(max: max)
          end

          private

            def max
              @max ||= boost.max
            end

            def boost
              Model::Boost.new(owners, context.redis)
            end
        end
      end
    end
  end
end
