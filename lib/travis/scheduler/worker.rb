require 'sidekiq'
require 'travis/scheduler/helper/runner'

module Travis
  module Scheduler
    class Worker
      include ::Sidekiq::Worker, Runner

      def perform(service, *args)
        run_service(service, *args)
      rescue => e
        puts e.message, e.backtrace
        raise
      end

      private

        def error(*msgs)
          logger.error(msgs.join("\n"))
        end

        def context
          Scheduler.context
        end

        def logger
          Scheduler.logger
        end
    end
  end
end
