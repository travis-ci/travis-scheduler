require 'travis/scheduler/helper/context'
require 'travis/scheduler/helper/logging'
require 'travis/scheduler/model/trial'

module Travis
  module Scheduler
    module Limit
      class ByOwner < Struct.new(:context, :owners, :job, :queued, :state, :config)
        include Helper::Context

        KEYS = [:by_boost, :by_config, :by_plan, :by_trial, :default]

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
              break report(key, value) if value && value > 0
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

          def by_trial
            max_trial if max_trial && trial.active?
          end

          def unlimited?
            owners.logins.any? { |login| config_for(login) == -1 }
          end

          def config_for(login)
            config[:limit][:by_owner][login].to_i
          end

          def max_trial
            config[:limit][:trial]
          end

          def default
            config[:limit][:default] || 5
          end

          def trial
            @trial ||= Model::Trial.new(owners, context.redis)
          end

          def report(key, value)
            key  = key.to_s.sub('by_', '').to_sym
            name = [job.owner.is_a?(User) ? 'user' : 'org', job.owner.login].join(' ')
            args = [name, key, value]
            args << owners.subscribed_owners.join(', ') if key == :plan
            msg  = MSGS[:"max_#{key}"] || MSGS[:max]
            reports << msg % args
            value
          end
      end
    end
  end
end
