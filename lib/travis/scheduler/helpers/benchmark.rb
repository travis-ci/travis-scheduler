require 'benchmark'

module Travis
  module Scheduler
    module Helpers
      module Benchmark
        class Benchmark
          attr_reader :logger, :context, :block, :status, :result, :error

          def initialize(context, logger, &block)
            @status = :starting
            @context = context
            @logger = logger
            @block = block
          end

          def realtime
            logger.info message
            time = ::Benchmark.realtime { call }
            logger.info message(time)
            raise error if error
            result
          end

          private

            def message(time = nil)
              "#{"#{context}:" if context} #{status} #{"#{time.round(3)}sec" if time}".strip
            end

            def call
              @result = block.call
              @status = :completed
            rescue => e
              @error = e
              @status = :errored
            end
        end

        def benchmark(context = nil, &block)
          Benchmark.new(context, Scheduler.logger, &block).realtime
        end
      end
    end
  end
end
