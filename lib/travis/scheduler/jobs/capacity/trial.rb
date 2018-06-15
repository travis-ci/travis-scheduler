require 'travis/scheduler/model/trial'

module Travis
  module Scheduler
    module Jobs
      module Capacity
        class Trial < Base
          def accept?(job)
            trial.active? && super
          end

          def report(status, job)
            super.merge(max: max)
          end

          private

            def max
              config[:limit][:trial].to_i
            end

            def trial
              @trial ||= Model::Trial.new(owners, context.redis)
            end
        end
      end
    end
  end
end
