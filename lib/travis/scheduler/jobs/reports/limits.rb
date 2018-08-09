require 'travis/scheduler/jobs/reports/totals'

module Travis
  module Scheduler
    module Jobs
      module Reports
        class Limits < Struct.new(:owners, :reports)
          MSGS = {
            queue:  '%s limited by queue %s: max=%s rejected=%s selected=%s',
            repo:   'repo %s limited by repo settings: max=%s rejected=%s selected=%s',
            stages: 'repo %s limited by stage on build_id=%s: rejected=%s selected=%s',
          }

          def to_a
            by_name.map { |name, data| report(name, data) }.flatten
          end

          private

            def report(name, data)
              send(:"report_#{name}", data)
            end

            def report_queue(data)
              msg :queue, data[0][:owner], data[0][:queue], data[0][:max], rejected(data), selected(data)
            end

            def report_repo(data)
              map_repos(data) do |slug, data|
                msg :repo, slug, data[0][:max], rejected(data), selected(data)
              end
            end

            def report_stages(data)
              map_repos(data) do |slug, data|
                map_builds(data) do |build_id, data|
                  msg :stages, slug, build_id, rejected(data), selected(data)
                end
              end
            end

            def map_repos(data, &block)
              repos(data).map do |slug|
                yield slug, data.select { |data| data[:repo_slug] == slug }
              end
            end

            def map_builds(data, &block)
              build_ids(data).map do |build_id|
                yield build_id, data.select { |data| data[:build_id] == build_id }
              end
            end

            def data_for(name)
              data.select { |data| data[:name] == name }
            end

            def names(data)
              data.map { |data| data[:name] }.uniq
            end

            def repos(data)
              data.map { |data| data[:repo_slug] }.uniq
            end

            def build_ids(data)
              data.map { |data| data[:build_id] }.uniq
            end

            def by_name
              reports.group_by { |row| row[:name] }
            end

            def selected(data)
              count(data, :accept)
            end

            def rejected(data)
              count(data, :reject)
            end

            def count(data, status)
              data.select { |data| data[:status] == status }.size
            end

            def msg(name, *args)
              MSGS[name] % args
            end
        end
      end
    end
  end
end

