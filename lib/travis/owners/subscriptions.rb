module Travis
  module Owners
    class Subscriptions < Struct.new(:owners, :config)
      def active?
        subscriptions.any?
      end

      def max_jobs
        @max_jobs ||= concurrencies.inject(&:+).to_i
      end

      def subscribers
        @subscribers ||= subscriptions.map(&:owner).map(&:login)
      end

      private

        def concurrencies
          subscriptions.map(&:concurrency).compact
        end

        def subscriptions
          owners.all.map(&:subscription).compact.select(&:active?)
        end
    end
  end
end
