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

        NAMES = %w(public boost plan config trial education)

        def accept(job)
          all.any? { |capacity| capacity.accept?(job) }
        end

        def reports
          all.map(&:reports).flatten
        end

        def accepted
          all.map(&:accepted).inject(&:+)
        end

        def exhausted?
          all.all?(&:exhausted?)
        end
        memoize :exhausted

        private

          def all
            @all ||= build.tap { |all| reduce(all) }
          end

          def reduce(all)
            all.inject(state.running) { |jobs, capacity| capacity.reduce(jobs) }
          end

          def build
            NAMES.map do |name|
              Capacity.const_get(name.camelize).new(context, owners, self)
            end
          end
      end
    end
  end
end
