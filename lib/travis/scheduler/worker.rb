require 'sidekiq'
require 'travis/scheduler/helper/runner'

module Travis
  module Scheduler
    class Worker
      include ::Sidekiq::Worker, Helper::Runner

      def perform(service, *args)
        inline(service, *normalize(args))
      end

      private

        def normalize(args)
          args.last[:jid] = jid if args.last.is_a?(Hash)
          args
        end

        def context
          Scheduler.context
        end
    end
  end
end
