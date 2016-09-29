require 'sidekiq'
require 'travis/scheduler/helper/runner'

module Travis
  module Scheduler
    class Worker
      include ::Sidekiq::Worker, Runner

      def perform(service, *args)
        run_service(service, *normalize(args))
      end

      private

        def normalize(args)
          args.last[:params] ||= { jid: jid } if args.last.is_a?(Hash)
        end

        def context
          Scheduler.context
        end
    end
  end
end
