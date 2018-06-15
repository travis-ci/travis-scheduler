module Travis
  module Scheduler
    module Jobs
      module Reports
        class ByRepo < Struct.new(:owners, :state, :reports)
          class Repo < Struct.new(:repo, :state, :reports)
            MSGS = {
              by_repo: 'repo %s: queueable=%s running=%s selected=%s waiting=%s'
            }

            def to_s
              msg(:by_repo, repo.slug, queueable, running, selected, waiting)
            end

            private

              def queueable
                state.queueable.select { |job| job.repository_id == repo.id }.size
              end

              def running
                state.running.select { |job| job.repository_id == repo.id }.size
              end

              def selected
                reports.select { |data| data[:status] == :accept }.size
              end

              def waiting
                queueable - selected
              end

              def msg(type, *args)
                MSGS[type] % args
              end
          end

          def to_s
            repos.map { |repo| Repo.new(repo, state, reports_for(repo)).to_s }.flatten
          end

          def repos
            Repository.where(id: repo_ids)
          end

          def repo_ids
            reports.map { |row| row[:repo_id] }
          end

          def reports_for(repo)
            reports.select { |data| data[:repo_id] == repo.id }
          end

          def reports
            @reports ||= super.select { |data| data[:type] == :capacity }
          end
        end
      end
    end
  end
end
