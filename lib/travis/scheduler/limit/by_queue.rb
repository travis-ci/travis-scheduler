require 'travis/scheduler/helper/context'
require 'travis/scheduler/helper/logging'

module Travis
  module Scheduler
    module Limit
      class ByQueue < Struct.new(:context, :owners, :job, :selected, :state, :_)
        include Helper::Context

        def enqueue?
          return true unless enabled?
          return true unless queue == ENV['BY_QUEUE_NAME']
          result = current < max
          report(max) if result
          result
        end

        def reports
          @reports ||= []
        end

        private

          def enabled?
            config[owners.key]
          end

          def current
            state.running_by_queue(job.queue) + selected.select { |j| j.queue == queue }.size
          end

          def max
            config[owners.key].to_i
          end

          def queue
            job.queue ||= Queue.new(job, context.config, nil).select
          end

          def repo
            job.repository
          end

          def report(value)
            reports << MSGS[:max] % [owners.to_s, "queue #{job.queue}", value]
            value
          end

          # TODO make this a repo setting at some point?
          def config
            @config ||= ENV['BY_QUEUE_LIMIT'].to_s.split(',').map { |pair| pair.split('=') }.to_h
          end
      end
    end
  end
end
