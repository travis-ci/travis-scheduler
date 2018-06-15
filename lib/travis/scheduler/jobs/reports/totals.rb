module Travis
  module Scheduler
    module Jobs
      module Reports
        class Totals < Struct.new(:owners, :state, :reports)
          MSGS = {
            totals: '%s: queueable=%s running=%s selected=%s waiting=%s'
          }

          def to_s
            msg :totals, owners.to_s, queueable, running, selected, waiting
          end

          private

            def queueable
              state.count_queueable
            end

            def running
              state.count_running
            end

            def selected
              @selected ||= capacities.select { |data| data[:status] == :accept }.size
            end

            def waiting
              queueable - selected
            end

            def capacities
              reports.select { |data| data[:type] == :capacity }
            end

            def msg(type, *args)
              MSGS[type] % args
            end
        end
      end
    end
  end
end
