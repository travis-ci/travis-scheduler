require 'travis/scheduler/helper/context'
require 'travis/scheduler/helper/locking'
require 'travis/scheduler/helper/runner'

module Travis
  module Scheduler
    class Ping < Struct.new(:context)
      include Helper::Context, Helper::Locking, Helper::Runner

      def start
        Thread.new do
          exclusive 'scheduler.ping', config do
            loop(&method(:run))
          end
        end
      end

      private

        def run
          ping
          sleep interval
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
