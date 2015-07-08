require 'multi_json'

require 'travis/support/amqp'
require 'travis/support/database'
require 'core_ext/kernel/run_periodically'
require 'travis/scheduler/services/enqueue_jobs'
require 'travis/support/logging'

module Travis
  module Scheduler
    class Schedule
      def setup
        Travis::Amqp.config = Travis.config.amqp
        Travis::Database.connect
        Travis::Exceptions::Reporter.start
        Travis::Metrics.setup

        declare_exchanges_and_queues
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
        rescue => e
          log_exception(e)
        end

        def declare_exchanges_and_queues
          channel = Travis::Amqp.connection.create_channel
          channel.exchange 'reporting', durable: true, auto_delete: false, type: :topic
          channel.queue 'builds.linux', durable: true, exclusive: false
        end
    end
  end
end
