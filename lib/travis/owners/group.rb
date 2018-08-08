module Travis
  module Owners
    class Group < Struct.new(:all, :config, :logger)
      include Enumerable

      def each(&block)
        all.each(&block)
      end

      def key
        @key ||= logins.join(':')
      end

      def logins
        @login ||= all.map(&:login).sort
      end

      def paid_capacity
        subscriptions.capacity
      end
      alias max_jobs paid_capacity

      def subscribed?
        subscriptions.active?
      end

      def subscribed_owners
        subscriptions.subscribers
      end

      def educational?
        all.any?(&:educational?)
      end

      def ==(other)
        key == other.key
      end

      def to_s
        all.map { |owner| [owner.is_a?(User) ? 'user' : 'org', owner.login].join(' ') }.join(', ')
      end

      def public_mode?(redis)
        return @public_mode if instance_variable_defined?(:@public_mode)
        @public_mode = all.any? { |owner| Features.owner_active?(:public_mode, owner) }
      end

      private

        def subscriptions
          @subscriptions ||= Subscriptions.new(self, plans, logger)
        end

        def plans
          config && config[:plans] || {}
        end
    end
  end
end
