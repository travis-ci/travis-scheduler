module Travis
  module Scheduler
    module Service
      def self.[](key)
        Travis::Registry[:service][key]
      end

      def run_service(key, *args)
        Service[key].new(*symbolize_keys(args)).run
      end

      def config
        Scheduler.config
      end

      private

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

require 'travis/scheduler/service/event'
require 'travis/scheduler/service/enqueue_job'
require 'travis/scheduler/service/enqueue_owners'
require 'travis/scheduler/service/notify'
