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

        ALL = %i(public boost config plan education trial)

        # TODO warn if no applicable :any capacity can be found
        def initialize(*)
          super
          reduce(*all)
        end

        def accept(job)
          enterprise? ? true : all.detect { |capacity| capacity.accept?(job) }
        end

        def reports
          all.map(&:reports).flatten
        end
        memoize :reports

        def accepted
          all.map(&:accepted).inject(&:+)
        end

        def exhausted?
          all.all?(&:exhausted?)
        end
        memoize :exhausted

        def msg
          "#{owners.to_s} capacities: #{all.map(&:to_s).join(', ')}"
        end

        private

          def all
            @all ||= ALL.map { |name| build(name) }.select(&:applicable?)
          end

          def reduce(*all)
            all.compact.inject(state.running) do |jobs, capacity|
              capacity.applicable? ? capacity.reduce(jobs) : jobs
            end
          end

          def build(name)
            Capacity.const_get(name.to_s.camelize).new(context, owners, self)
          end

          def enterprise?
            !!context.config[:enterprise]
          end
      end
    end
  end
end
