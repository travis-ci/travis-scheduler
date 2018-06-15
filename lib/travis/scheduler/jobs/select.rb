require 'travis/honeycomb'
require 'travis/scheduler/jobs/report'
require 'travis/scheduler/jobs/state'

module Travis
  module Scheduler
    module Jobs
      class Select < Struct.new(:context, :owners)
        def run
          select
          honeycomb
        end

        def selected
          @selected ||= []
        end

        def reports
          Report.new(owners, state, limits.reports + capacities.reports).to_a
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

          def honeycomb
            Travis::Honeycomb.context.add('scheduler.stats',
              running: state.count_running,
              enqueued: selected.size,
              waiting: state.count_queueable - selected.size,
              # waiting_for_concurrency: @waiting_by_owner,
              concurrent: state.count_running + selected.size
            )
          end
      end
    end
  end
end
