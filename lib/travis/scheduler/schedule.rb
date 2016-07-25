require 'multi_json'

require 'core_ext/kernel/run_periodically'
require 'travis/amqp'
require 'travis/support/database'
require 'travis/scheduler/helpers/locking'
require 'travis/scheduler/services/enqueue_jobs'
require 'travis/support/exceptions'
require 'travis/scheduler/support/sidekiq'
require 'travis/scheduler/github'

module Travis
  module Scheduler
    class Schedule
      extend Travis::Exceptions::Handling
      include Helpers::Locking

      def setup
        Travis::Amqp.setup(config.amqp.to_h)
        Travis::Database.connect(config.database.to_h)
        Travis::Exceptions::Reporter.start
        Travis::Metrics.setup
        Support::Sidekiq.setup(config)
        Support::Features.setup(config)
        Travis::Scheduler::Github.setup

        if ENV['PUBLISH_POOL_ENABLED'] =~ /^(true|1)$/i
          setup_publish_pool
        end

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

        # thread pool for parallel publishing of jobs to rabbitmq
        #
        # use :caller_runs fallback policy to block the main thread
        # when no worker threads are available -- this creates
        # backpressure and prevents memory from leaking.
        #
        # make sure to also scale the DATABASE_POOL_SIZE env var
        # when you scale these values.
        def setup_publish_pool
          @publish_pool ||= begin
            Travis.logger.info("Setting up Publish Thread Pool")
            Concurrent::ThreadPoolExecutor.new(
              min_threads: ENV['PUBLISH_POOL_MIN_THREADS'] || 4,
              max_threads: ENV['PUBLISH_POOL_MIN_THREADS'] || 4,
              max_queue: ENV['PUBLISH_POOL_MAX_QUEUE'] || 10,
              fallback_policy: :caller_runs
            )
          end
        end

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
