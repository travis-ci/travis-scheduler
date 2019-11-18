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
          limit = config[plan[:plan].to_sym].tap { |limit| missing_plan(plan[:plan]) unless limit }

          # Increment this by 1 as our original values are being increased up by
          #   one as part of our "free 1-job private repo" plan project,
          #   expected to be launched in December, 2018.
          #
          # https://github.com/travis-ci/product/issues/97
          #

          if plan[:owner].is_a?(User) && limit
            limit += 1
          end

          limit
        end

        def missing_plan(plan)
          logger.warn MSGS[:missing_plan] % [plan, owners.to_s]
        end

        def plans
          subscriptions.map { |sub|
            if sub.selected_plan && sub.owner
              { plan: sub.selected_plan, owner: sub.owner }
            end
          }.compact
        end

        def subscriptions
          owners.all.map(&:subscription).compact.select(&:active?)
        end
    end
  end
end
