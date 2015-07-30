$stdout.sync = true

require 'travis/support'
require 'travis/support/logging'
require 'travis/support/logger'
require 'travis/scheduler/config'
require 'travis/scheduler/schedule'

module Travis
  module Scheduler
    class << self
      def env
        config.env
      end

      def logger
        @logger ||= Logger.configure(Logger.new(STDOUT))
      end

      def logger=(logger)
        @logger = Logger.configure(logger)
      end

      def uuid=(uuid)
        Thread.current[:uuid] = uuid
      end

      def uuid
        Thread.current[:uuid] ||= SecureRandom.uuid
      end

      def config
        @config ||= Config.load
      end
    end
  end

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
