# frozen_string_literal: true

require 'travis/scheduler/helper/context'
require 'travis/scheduler/helper/honeycomb'
require 'travis/scheduler/helper/metrics'
require 'travis/scheduler/jobs/report'
require 'travis/scheduler/jobs/state'

module Travis
  module Scheduler
    module Jobs
      class Select < Struct.new(:context, :owners)
        include Helper::Metrics
        include Helper::Honeycomb
        include Helper::Context

        def run
          select
          meter
          honeycomb
        end

        def selected
          @selected ||= []
        end

        def reports
          [capacities.msg] + report.msgs
        end

        private

        def select
          state.queueable.each do |job|
            selected << job if accept(job)
            break if capacities.exhausted?
          end
        end

        def accept(job)
          limits.accept(job) { capacities.accept(job) }
        end

        def limits
          @limits ||= Limits.new(context, owners, state)
        end

        def capacities
          @capacities ||= Capacities.new(context, owners, state)
        end

        def state
          @state ||= State.new(context, owners)
        end

        def report
          @report ||= Report.new(owners, state, limits.reports + capacities.reports)
        end

        def meter
          report.metrics.each do |key, value|
            gauge("jobs.#{key}.count", value)
          end
        end

        def honeycomb
          super('scheduler.stats' => report.metrics.merge(
            running: state.count_running,
            enqueued: selected.size,
            waiting: state.count_queueable - selected.size,
            waiting_for_concurrency: report.waiting_for_concurrency,
            concurrent: state.count_running + selected.size
          ))
        end
      end
    end
  end
end
