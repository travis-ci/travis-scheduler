require 'travis/scheduler/helper/memoize'
require 'travis/scheduler/jobs/capacity/base'
require 'travis/scheduler/jobs/capacity/boost'
require 'travis/scheduler/jobs/capacity/config'
require 'travis/scheduler/jobs/capacity/education'
require 'travis/scheduler/jobs/capacity/plan'
require 'travis/scheduler/jobs/capacity/public'
require 'travis/scheduler/jobs/capacity/trial'

module Travis
  module Scheduler
    module Jobs
      class Capacities < Struct.new(:context, :owners, :state)
        include Helper::Memoize

        NAMES = %i(public boost plan config education trial)

        def accept(job)
          public.accept?(job) || other.try(:accept?, job)
        end

        def reports
          active.map(&:reports).flatten
        end

        def accepted
          active.map(&:accepted).inject(&:+)
        end

        def exhausted?
          active.all?(&:exhausted?)
        end
        memoize :exhausted

        private

          def active
            [public, other].compact
          end

          def public
            all.first
          end

          def other
            all[1..-1].detect { |capacity| capacity.applicable? }
          end

          # as only one out of boost, plan, config etc is supposed to be used
          # if applicable we wouldn't have to build and reduce them all.
          def all
            @all ||= reduce(NAMES.map { |name| build(name) })
          end

          def reduce(all)
            all.inject(state.running) do |jobs, capacity|
              capacity.applicable? ? capacity.reduce(jobs) : jobs
            end
            all
          end

          def build(name)
            Capacity.const_get(name.to_s.camelize).new(context, owners, self)
          end
      end
    end
  end
end
