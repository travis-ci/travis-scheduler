module Travis
  module Scheduler
    module Model
      class Subscriptions < Struct.new(:owners, :config)
        def max_jobs
          @max_jobs ||= plan_limits.inject(&:+).to_i
        end

        def subscribers
          @subscribers ||= subscriptions.map(&:owner).map(&:login)
        end

        private

          def plan_limits
            plans.map { |plan| plan_limit(plan) }.compact
          end

          def plan_limit(plan)
            config[plan.to_sym]
          end

          def plans
            subscriptions.map(&:selected_plan).compact
          end

          def subscriptions
            owners.all.map(&:subscription).compact.select(&:active?)
          end
      end
    end
  end
end
