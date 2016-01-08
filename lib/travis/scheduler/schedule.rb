require 'multi_json'

require 'core_ext/kernel/run_periodically'
require 'travis/support/amqp'
require 'travis/support/database'
require 'travis/scheduler/services/enqueue_jobs'
require 'travis/support/exceptions'
require 'travis/scheduler/support/sidekiq'

module Travis
  module Scheduler
    class Schedule
      extend Travis::Exceptions::Handling

      def setup
        Travis::Amqp.config = config.amqp.to_h
        Travis::Database.connect(config.database.to_h)
        Travis::Exceptions::Reporter.start
        Travis::Metrics.setup
        Support::Sidekiq.setup(config)
        Support::Features.setup(config)

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
        end
        rescues :enqueue_jobs

        def declare_exchanges_and_queues
          channel = Travis::Amqp.connection.create_channel
          channel.exchange 'reporting', durable: true, auto_delete: false, type: :topic
          channel.queue 'builds.linux', durable: true, exclusive: false
        end

        def config
          Scheduler.config
        end
    end
  end
end
