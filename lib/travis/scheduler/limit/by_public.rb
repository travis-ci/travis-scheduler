require 'travis/scheduler/helper/context'
require 'travis/scheduler/helper/logging'
require 'travis/scheduler/model/trial'

module Travis
  module Scheduler
    module Limit
      class ByPublic < Struct.new(:context, :owners, :job, :selected, :state, :config)
        include Helper::Context

        def enqueue?
          p [:public, job.id, current, max, job.public?, current < max]
          current < max if job.public? && owners.merge_mode?
        end

        def reports
          @reports ||= []
        end

        private

          def current
            state.running_by_owners_public + selected.select(&:public?).size
          end

          def max
            config[:limit][:public] || 5
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
