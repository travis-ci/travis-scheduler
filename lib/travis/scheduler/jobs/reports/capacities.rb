require 'travis/scheduler/jobs/reports/totals'

module Travis
  module Scheduler
    module Jobs
      module Reports
        class Capacities < Struct.new(:owners, :reports)
          include Helper::Memoize

          MSGS = {
            report: '%{owner} %{name} capacity: running=%{reduced} max=%{max} selected=%{selected}',
          }

          def msgs
            data.map { |data| msg :report, data }
          end

          def metrics
            data.map { |data| [metrics_key(data[:name]), data[:selected]] }
          end

          private

            def report(data)
              msg :report, data[:owner], data[:name], data[:reduced], data[:max], data[:selected]
            end

            def data
              by_name.map { |name, rows| map(name, rows) }
            end
            memoize :data

            def by_name
              reports.group_by { |row| row[:name] }
            end

            def map(name, rows)
              {
                name: name,
                owner: rows[0][:owner],
                max: rows[0][:max],
                reduced: rows[0][:reduced],
                selected: selected(rows).size
              }
            end

            def selected(data)
              data.select { |data| data[:status] == :accept }
            end

            def metrics_key(name)
              "jobs.capacities.#{name}.count"
            end

            def msg(name, args)
              MSGS[name] % args
            end
        end
      end
    end
  end
end
