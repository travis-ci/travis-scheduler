require 'sidekiq'
require 'travis/scheduler/helper/runner'
require 'marginalia'

module Travis
  module Scheduler
    class Worker
      include ::Sidekiq::Worker, Helper::Runner

      def perform(service, *args)
        puts "the name of service is #{service}"
        ::Marginalia.set('service', service)
        inline(service, *normalize(args))
      end

      private

        def normalize(args)
          args = symbolize_keys(args)
          args.last[:jid] ||= jid if args.last.is_a?(Hash)
          args
        end

        def context
          Scheduler.context
        end

        def symbolize_keys(obj)
          case obj
          when Array
            obj.map { |obj| symbolize_keys(obj) }
          when ::Hash
            obj.map { |key, value| [key.to_sym, symbolize_keys(value)] }.to_h
          else
            obj
          end
        end
    end
  end
end
