require 'multi_json'

require 'core_ext/kernel/run_periodically'
require 'travis/scheduler/helper/locking'
require 'travis/scheduler/services/enqueue_jobs'

module Travis
  module Scheduler
    class Schedule
      extend Travis::Exceptions::Handling
      include Locking

      def initialize
        declare_exchanges_and_queues
      end

      def run
        enqueue_jobs_periodically
      end

      private

        def enqueue_jobs_periodically
          run_periodically(Travis.config.interval) do
            enqueue_jobs
          end
          sleep
        end

        def enqueue_jobs
          exclusive do
            time { Services::EnqueueJobs.run(@publish_pool) }
          end
        end
        rescues :enqueue_jobs

        def declare_exchanges_and_queues
          channel = Travis::Amqp.connection.create_channel
          channel.exchange 'reporting', durable: true, auto_delete: false, type: :topic
          channel.queue 'builds.linux', durable: true, exclusive: false
        end

        def time(&block)
          Metriks.timer('schedule.enqueue_jobs').time(&block)
        end

        def exclusive(&block)
          super('schedule.enqueue_jobs', &block)
        end

        def config
          Scheduler.config
        end
    end
  end
end
