# frozen_string_literal: true

module Travis
  module Scheduler
    module Jobs
      module Capacity
        class Trial < Base
          include Helper::Memoize

          def applicable?
            !on_metered_plan? && com? && active?
          end

          def accept?(job)
            active? && super
          end

          def report(status, job)
            super.merge(max:)
          end

          private

          def max
            config[:limit][:trial].to_i
          end

          def active?
            owners.any? { |owner| owner.trial.try(:active?) }
          end
          memoize :active?

          def com?
            config.com?
          end
        end
      end
    end
  end
end
