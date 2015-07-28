require 'multi_json'

require 'core_ext/kernel/run_periodically'
require 'travis/support/amqp'
require 'travis/support/database'
require 'travis/scheduler/services/enqueue_jobs'
require 'travis/scheduler/counter'
require 'travis/support/logging'
require 'travis/scheduler/support/sidekiq'

module Travis
  module Scheduler
    class Schedule
      include Travis::Logging

      def setup
        Travis::Amqp.config = Travis.config.amqp
        Travis::Database.connect
        Travis::Exceptions::Reporter.start
        Travis::Metrics.setup
        Support::Sidekiq.setup(Travis.config)

        declare_exchanges_and_queues
        @exception_count = 0
      end

      def run
        enqueue_jobs_periodically
      end

      private

        def enqueue_jobs_periodically
          run_periodically(Travis.config.interval) do
            Metriks.timer("schedule.enqueue_jobs").time { enqueue_jobs }
          end
          sleep
        end

        def enqueue_jobs
          Services::EnqueueJobs.run
          exception_counter.reset
        rescue => e
          exception_counter.increment
          raise(e) if exception_counter.total >= Travis.config.scheduler.exception_threshold
          log_exception(e)
        end

        def declare_exchanges_and_queues
          channel = Travis::Amqp.connection.create_channel
          channel.exchange 'reporting', durable: true, auto_delete: false, type: :topic
          channel.queue 'builds.linux', durable: true, exclusive: false
        end

        def exception_counter
          @exception_counter ||= ::Travis::Scheduler::Counter.new
        end
    end
  end
end
