require 'forwardable'

module Travis
  module Scheduler
    module Context
      class Context < Struct.new(:config, :amqp, :features, :logger, :metrics, :redis, :params)
        def initialize(*)
          super
          self.params ||= {}
        end
      end

      def self.new(*args)
        Context.new(*args)
      end

      extend Forwardable

      def_delegators :context, :config, :amqp, :features, :logger, :metrics, :redis, :params

      def initialize(context, *args)
        fail("First argument to #{self.class}#initialize must be a Context. #{context} given.") unless context.is_a?(Context)
        super
      end
    end
  end
end
