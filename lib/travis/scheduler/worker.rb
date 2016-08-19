require 'sidekiq'

module Travis
  module Scheduler
    class Worker
      include ::Sidekiq::Worker

      def perform(service, *args)
        Services[service].new(*symbolize_keys(args)).run
      rescue => e
        error e.message, e.backtrace
        raise
      end

      private

        def error(*msgs)
          logger.error(msgs.join("\n"))
        end

        def logger
          Scheduler.logger
        end

        def symbolize_keys(obj)
          case obj
          when Array
            obj.map { |obj| symbolize_keys(obj) }
          when ::Hash
            obj.inject({}) do |hash, (key, value)|
              key = key.respond_to?(:to_sym) ? key.to_sym : key
              hash[key] = symbolize_keys(value)
              hash
            end
          else
            obj
          end
        end
    end
  end
end
