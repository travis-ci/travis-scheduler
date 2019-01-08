module Travis
  module Scheduler
    module Jobs
      module Limit
        class Queue < Base
          def accept?(job)
            return true unless enabled? && queue(job) == name
            super
          end

          private

            def max(job)
              num = config.fetch(owners.key, default)
              num && num.to_i
            end

            def running(job)
              state.count_running_by_queue(name)
            end

            def queue(job)
              job.queue ||= Travis::Queue.new(job, context.config, nil).select
            end

            def enabled?
              config[owners.key] || default > 0
            end

            def name
              ENV['BY_QUEUE_NAME']
            end

            def default
              ENV['BY_QUEUE_DEFAULT'].to_i
            end

            def config
              @config ||= to_h(ENV['BY_QUEUE_LIMIT'].to_s)
            end

            def to_h(str)
              str.split(',').map { |pair| pair.split('=') }.to_h
            end

            def report(status, job)
              {
                type: :limit,
                name: :queue,
                status: status,
                owner: owners.to_s,
                id: job.id,
                queue: job.queue,
                max: max(job),
                running: running(job)
              }
            end
        end
      end
    end
  end
end
