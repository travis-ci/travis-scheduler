require 'travis/scheduler/jobs/reports/totals'

module Travis
  module Scheduler
    module Jobs
      module Reports
        class Capacities < Struct.new(:owners, :reports)
          MSGS = {
            report: '%s %s capacity: total=%s running=%s selected=%s',
          }

          def to_a
            by_name.map { |name, data| report(name, data) }
          end

          private

            def by_name
              reports.group_by { |row| row[:name] }
            end

            def report(name, data)
              msg :report, data[0][:owner], name, data[0][:max], data[0][:reduced], selected(data)
            end

            def selected(data)
              data.select { |data| data[:status] == :accept }.size
            end

            def msg(name, *args)
              MSGS[name] % args
            end
        end
      end
    end
  end
end
