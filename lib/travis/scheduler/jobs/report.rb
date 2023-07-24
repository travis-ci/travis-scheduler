require 'travis/scheduler/helper/memoize'
require 'travis/scheduler/jobs/reports/by_repo'
require 'travis/scheduler/jobs/reports/capacities'
require 'travis/scheduler/jobs/reports/limits'
require 'travis/scheduler/jobs/reports/totals'

module Travis
  module Scheduler
    module Jobs
      class Report < Struct.new(:owners, :state, :reports)
        include Helper::Memoize

        WARN_QUEUE_SIZE = ENV.fetch('WARN_QUEUE_SIZE', 10_000).to_i

        MSGS = {
          default: '%s capacity for %s: total=%s running=%s accepted=%s',
          queue: 'limited by queue %s for %s: max=%s rejected=%s accepted=%s',
          repo: 'limited by repo settings on %s: max=%s rejected=%s accepted=%s',
          stages: 'limited by stage repo=%s build_id=%s: rejected=%s accepted=%s',
          summary: '%s: queueable=%s running=%s accepted=%s waiting=%s',
          excess: '%s excessive queue size %s'
        }

        def msgs
          capacities.msgs + limits.msgs + by_repo.msgs + [totals.msg] + warnings
        end

        def metrics
          capacities.metrics
        end
        memoize :metrics

        def waiting_for_concurrency
          totals.waiting_for_concurrency
        end

        private

        def capacities
          Reports::Capacities.new(owners, data_for(:capacity))
        end
        memoize :capacities

        def limits
          Reports::Limits.new(owners, data_for(:limit))
        end

        def by_repo
          Reports::ByRepo.new(owners, state, reports)
        end

        def totals
          Reports::Totals.new(owners, state, reports)
        end
        memoize :totals

        def warnings
          msgs = []
          msgs << format(MSGS[:excess], owners.to_s, queue_size) if queue_size > WARN_QUEUE_SIZE
          msgs
        end

        def queue_size
          state.count_queueable
        end

        def data_for(type)
          reports.select { |report| report[:type] == type }
        end
      end
    end
  end
end
