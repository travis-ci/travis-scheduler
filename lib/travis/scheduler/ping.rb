require 'travis/scheduler/helper/context'
require 'travis/scheduler/helper/locking'
require 'travis/scheduler/helper/logging'
require 'travis/scheduler/helper/runner'

module Travis
  module Scheduler
    class Ping < Struct.new(:context)
      include Helper::Context, Helper::Locking, Helper::Logging, Helper::Runner

      def start
        Thread.new do
          loop(&method(:run))
        end
      end

      private

        def run
          exclusive 'scheduler.ping', config do
            ping
            sleep interval
          end
        rescue => e
          logger.error e.message, e.backtrace
        end

        def ping
          async :ping
        end

        def interval
          config[:ping][:interval]
        end
    end
  end
end
