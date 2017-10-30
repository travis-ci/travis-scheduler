require 'travis/scheduler/helper/context'
require 'travis/scheduler/helper/logging'
require 'travis/scheduler/model/settings'

module Travis
  module Scheduler
    module Limit
      class ByQueue < Struct.new(:context, :reports, :owners, :job, :selected, :state, :_)
        include Helper::Context

        def enqueue?
          return true unless queue == ENV['BY_QUEUE_NAME']
          result = current < max
          report(max) if result
          result
        end

        private

          def queue
            job.queue ||= Queue.new(job, context.config, nil).select
          end

          def current
            state.running_by_queue(job.queue) + selected.select { |j| j.queue == queue }.size
          end

          def max
            by_config || by_setting || default
          end

          def by_config
            config[owners.key].to_i if config.key?(owners.key)
          end

          def by_setting
            # p settings[:by_queue_enabled].enabled?
            settings[:by_queue_enabled].enabled? && settings[:by_queue].value
          end

          def repo
            job.repository
          end

          def default
            ENV.fetch('BY_QUEUE_DEFAULT', 2).to_i
          end

          def config
            @config ||= ENV['BY_QUEUE_LIMIT'].to_s.split(',').map { |pair| pair.split('=') }.to_h
          end

          def settings
            @settings ||= Model::Settings.new(owners)
          end

          def report(value)
            reports << MSGS[:max] % [owners.to_s, "queue #{job.queue}", value]
            value
          end
      end
    end
  end
end
