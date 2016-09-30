require 'forwardable'

module Travis
  module Scheduler
    module Helper
      module Context
        extend Forwardable

        def_delegators :context, :config, :amqp, :features, :logger, :metrics, :redis

        def initialize(context, *args)
          fail("First argument to #{self.class}#initialize must be a Context. #{context} given.") unless context.is_a?(Scheduler::Context)
          super
        end
      end
    end
  end
end
