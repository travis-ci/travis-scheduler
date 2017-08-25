module Travis
  module Owners
    class Group < Struct.new(:all, :config)
      include Enumerable

      def each(&block)
        all.each(&block)
      end

      def key
        logins.join(':')
      end

      def logins
        all.map(&:login)
      end

      def max_jobs
        subscriptions.max_jobs
      end

      def subscribed?
        subscriptions.active?
      end

      def subscribed_owners
        subscriptions.subscribers
      end

      def ==(other)
        key == other.key
      end

      def to_s
        all.map { |owner| [owner.is_a?(User) ? 'user' : 'org', owner.login].join(' ') }.join(', ')
      end

      def public_api?(redis)
        return @public_api if instance_variable_defined?(:@public_api)
        @public_api = all.any? { |owner| Features.owner_active?(:public_api, owner) }
      end

      private

        def subscriptions
          @subscriptions ||= Subscriptions.new(self, plans)
        end

        def plans
          config && config[:plans] || {}
        end
    end
  end
end
