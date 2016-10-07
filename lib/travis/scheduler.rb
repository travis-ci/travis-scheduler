require 'redis'
require 'travis'
require 'travis/amqp'
require 'travis/exceptions'
require 'travis/logger'
require 'travis/metrics'
require 'travis/scheduler/config'
require 'travis/scheduler/record'
require 'travis/scheduler/ping'
require 'travis/scheduler/service'
require 'travis/scheduler/support/features'
require 'travis/scheduler/support/sidekiq'
require 'travis/scheduler/worker'
require 'travis/support/branch_validator' # TODO move to gatekeeper
require 'travis/support/database'

module Travis
  module Scheduler
    Context = Struct.new(:config, :amqp, :features, :logger, :metrics, :redis)

    class << self
      attr_reader :metrics

      def setup
        Amqp.setup(config.amqp.to_h, logger)
        Database.connect(config.database.to_h)
        Exceptions.setup(config, config.env, logger)
        @metrics = Metrics.setup(config.metrics, logger)
        Sidekiq.setup(config, logger)
        Features.setup(config)
      end

      def context
        @context ||= Context.new(config, nil, nil, logger, metrics, redis)
      end

      def config
        @config ||= Config.load
      end

      def env
        config.env
      end

      def logger
        @logger ||= Logger.configure(Logger.new(STDOUT), config)
      end

      def logger=(logger)
        @logger = Logger.configure(logger, config)
      end

      def redis
        @redis ||= Redis.connect(config[:redis].to_h) # TODO should be a pool, no?
      end

      def ping
        Ping.new(context).start if ENV['PING']
      end
    end
  end

  # TODO used by travis-settings, apparently
  class << self
    def env
      Scheduler.env
    end

    def config
      Scheduler.config
    end

    def logger
      Scheduler.logger
    end
  end
end
