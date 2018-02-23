require 'travis/scheduler/helper/context'
require 'travis/scheduler/helper/logging'
require 'travis/scheduler/model/trial'

module Travis
  module Scheduler
    module Limit
      class ByOwner < Struct.new(:context, :reports, :owners, :job, :selected, :state, :config)
        include Helper::Context

        KEYS = [:by_boost, :by_config, :by_plan, :by_trial, :default]

        def enqueue?
          unlimited || current < max
        end

        private

          def current
            without_public(state.running_by_owners + selected.size)
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
            with_public(owners.max_jobs)
          end

          def by_trial
            max_trial if max_trial && trial.active?
          end

          def unlimited?
            owners.logins.any? { |login| config_for(login) == -1 }
          end

          def config_for(login)
            with_public(config[:limit][:by_owner][login].to_i)
          end

          def max_trial
            with_public(config[:limit][:trial])
          end

          def default
            with_public(config[:limit][:default] || 5)
          end

          def with_public(max)
            max = max + config[:limit][:public].to_i if max.to_i > 0 && job.public? && public_mode?
            max
          end

          def without_public(count)
            count = count - running_and_selected_public_jobs_upto_config_limit if !job.public? && public_mode?
            count
          end

          def running_and_selected_public_jobs_upto_config_limit
            count = state.running_by_owners_public + selected.select(&:public?).size
            count = [count, config[:limit][:public].to_i].min if config[:limit][:public]
            count
          end

          def public_mode?
            owners.public_mode?(context.redis)
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
