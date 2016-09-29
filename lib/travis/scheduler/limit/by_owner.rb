require 'travis/scheduler/helper/context'
require 'travis/scheduler/helper/logging'

module Travis
  module Scheduler
    class Limit
      class ByOwner < Struct.new(:context, :owners, :job, :queued, :state, :config)
        include Context

        KEYS = [:by_boost, :by_config, :by_plan, :default]

        def enqueue?
          unlimited || current < max || throw(:result, :limited)
        end

        def reports
          @reports ||= []
        end

        private

          def current
            state.running_by_owners + queued
          end

          def max
            KEYS.each do |key|
              value = send(key)
              break report(key, value) if value > 0
            end
          end

          def unlimited
            report :unlimited, true if unlimited?
          end

          def by_boost
            owners.logins.map { |login| state.boost_for(login) }.max
          end

          def by_config
            owners.logins.map { |login| config_for(login) }.max
          end

          def by_plan
            owners.max_jobs
          end

          def unlimited?
            owners.logins.any? { |login| config_for(login) == -1 }
          end

          def config_for(login)
            config[:limit][:by_owner][login].to_i
          end

          def default
            config[:limit][:default] || 5
          end

          def report(key, value)
            key  = key.to_s.sub('by_', '').to_sym
            args = [job.owner.login, key, value]
            args << owners.subscribed_owners.join(', ') if key == :plan
            msg  = MSGS[:"max_#{key}"] || MSGS[:max]
            reports << msg % args
            value
          end
      end
    end
  end
end
