module Travis
  module Owners
    class Subscriptions < Struct.new(:owners, :config, :logger)
      MSGS = {
        missing_plan: '[missing_plan] Plan missing from application config: %s (%s)'
      }

      def active?
        subscriptions.any?
      end

      def capacity
        @capacity ||= plan_limits.inject(&:+).to_i
      end
      alias max_jobs capacity

      def subscribers
        @subscribers ||= subscriptions.map(&:owner).map(&:login)
      end

      private

        def plan_limits
          plans.map { |plan| plan_limit(plan) }.compact
        end

        def plan_limit(plan)
          config[plan.to_sym].tap { |limit| missing_plan(plan) unless limit }
          # config[plan.to_sym].tap do |limit| 
          #   missing_plan(plan) unless limit
          #   limit += 1 unless plan == "travis-ci-one-free-build" || subscriptions.last.owner_type == "Organization"
          #   limit
          end
        end

        def missing_plan(plan)
          logger.warn MSGS[:missing_plan] % [plan, owners.to_s]
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
