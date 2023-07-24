require 'travis/scheduler/helper/memoize'

module Travis
  module Scheduler
    module Jobs
      module Reports
        class Totals < Struct.new(:owners, :state, :reports)
          include Helper::Memoize

          MSGS = {
            totals: '%s: queueable=%s running=%s selected=%s total_waiting=%s waiting_for_concurrency=%s'
          }

          def msg
            format(MSGS[:totals], owners.to_s, queueable, running, selected, total_waiting, waiting_for_concurrency)
          end

          def waiting_for_concurrency
            total_waiting - limited
          end

          private

          def queueable
            state.count_queueable
          end

          def running
            state.count_running
          end

          def total_waiting
            queueable - selected
          end

          def selected
            capacities.select { |data| data[:status] == :accept }.size
          end
          memoize :selected

          def limited
            limits.select { |data| data[:status] == :reject }.size
          end

          def capacities
            reports.select { |data| data[:type] == :capacity }
          end

          def limits
            reports.select { |data| data[:type] == :limit }
          end
        end
      end
    end
  end
end
