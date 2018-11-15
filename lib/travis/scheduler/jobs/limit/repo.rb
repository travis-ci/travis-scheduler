module Travis
  module Scheduler
    module Jobs
      module Limit
        class Repo < Base
          def accept?(job)
            return true unless max(job)
            super
          end

          private

            def max(job)
              num = job.repository.settings.maximum_number_of_builds
              num > 0 ? num : nil
            end

            def running(job)
              state.count_running_by_repo(job.repository.id)
            end

            def report(status, job)
              {
                type: :limit,
                name: :repo,
                status: status,
                repo_slug: job.repository.slug,
                id: job.id,
                max: max(job)
              }
            end
        end
      end
    end
  end
end
