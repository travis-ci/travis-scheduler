module Travis
  module Scheduler
    module Jobs
      module Capacity
        class Trial < Base
          include Helper::Memoize

          def applicable?
            active?
          end

          def accept?(job)
            active? && super
          end

          def report(status, job)
            super.merge(max: max)
          end

          private

            def max
              config[:limit][:trial].to_i
            end

            def active?
              owners.any? { |owner| owner.trial.try(:active?) }
            end
            memoize :active?
        end
      end
    end
  end
end
