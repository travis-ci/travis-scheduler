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

        ANY = %i(boost plan config education trial)

        # TODO warn if no applicable :any capacity can be found
        def initialize(*)
          super
          reduce(public, any)
        end

        def accept(job)
          public.accept?(job) || any.try(:accept?, job)
        end

        def reports
          active.map(&:reports).flatten
        end
        memoize :reports

        def accepted
          active.map(&:accepted).inject(&:+)
        end

        def exhausted?
          active.all?(&:exhausted?)
        end
        memoize :exhausted

        def to_s
          "#{owners.to_s} capacities: #{active.map(&:to_s).join(', ')}"
        end

        private

          def active
            [public, any].compact
          end

          def public
            @public ||= build(:public)
          end

          def any
            @any ||= ANY.map { |name| build(name) }.detect(&:applicable?)
          end

          def reduce(*all)
            all.compact.inject(state.running) do |jobs, capacity|
              capacity.applicable? ? capacity.reduce(jobs) : jobs
            end
          end

          def build(name)
            Capacity.const_get(name.to_s.camelize).new(context, owners, self)
          end
      end
    end
  end
end
