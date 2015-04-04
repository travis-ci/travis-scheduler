require 'multi_json'

require 'travis'
require 'travis/model'
require 'travis/states_cache'
require 'travis/support/amqp'
require 'core_ext/kernel/run_periodically'
require 'travis/support/logging'

module Travis
  module Scheduler
    class Schedule
      include Travis::Logging

      def setup
        Travis::Async.enabled = true
        Travis::Amqp.config = Travis.config.amqp

        Travis.logger.info('[schedule] connecting to database')
        Travis::Database.connect

        if Travis.config.logs_database
          Travis.logger.info('[schedule] connecting to logs database')
          Log.establish_connection 'logs_database'
          Log::Part.establish_connection 'logs_database'
        end

        Travis.logger.info('[schedule] setting up sidekiq')
        Travis::Async::Sidekiq.setup(Travis.config.redis.url, Travis.config.sidekiq)

        Travis.logger.info('[schedule] starting exceptions reporter')
        Travis::Exceptions::Reporter.start

        Travis.logger.info('[schedule] setting up metrics')
        Travis::Metrics.setup

        Travis.logger.info('[schedule] setting up notifications')
        Travis::Notification.setup

        Travis.logger.info('[schedule] setting up addons')
        Travis::Addons.register

        declare_exchanges_and_queues
      end

      def run
        Travis.logger.info('[schedule] starting the onslaught')
        enqueue_jobs_periodically
        sleep
      end

      private

        def enqueue_jobs_periodically
          run_periodically(Travis.config.queue.interval) do
            Metriks.timer("schedule.enqueue_jobs").time { enqueue_jobs }
          end
        end

        def enqueue_jobs
          Travis.run_service(:enqueue_jobs)
        rescue => e
          log_exception(e)
        end

        def declare_exchanges_and_queues
          Travis.logger.info('[schedule] connecting to amqp')
          channel = Travis::Amqp.connection.create_channel
          channel.exchange 'reporting', durable: true, auto_delete: false, type: :topic
          channel.queue 'builds.linux', durable: true, exclusive: false
        end
    end
  end
end
