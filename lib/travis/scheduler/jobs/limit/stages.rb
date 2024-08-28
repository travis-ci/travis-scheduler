# frozen_string_literal: true

require 'travis/scheduler/model/stages'

module Travis
  module Scheduler
    module Jobs
      module Limit
        class Stages < Base
          def accept?(job)
            return true unless job.stage_number

            queueable?(job) ? accept(job) : reject(job)
          end

          private

          def queueable?(job)
            queueable(job).map { |attrs| attrs[:id] }.include?(job.id)
          end

          def queueable(job)
            Travis::Stages.build(jobs(job.source_id), job.source_id).startable
          end

          def jobs(build_id)
            sort(state.by_build(build_id)).map { |job| attrs(job) }
          end

          NUM = ->(job) { job.stage_number.split('.').map(&:to_i) }

          def sort(jobs)
            jobs.sort { |lft, rgt| NUM.call(lft) <=> NUM.call(rgt) }
          end

          def attrs(job)
            {
              id: job.id,
              stage: job.stage_number,
              state: job.finished? ? :finished : :created
            }
          end

          def report(status, job)
            {
              type: :limit,
              name: :stages,
              status:,
              id: job.id,
              repo_slug: job.repository.slug,
              build_id: job.source_id,
              stage: job.stage_number.split('.').first
            }
          end
        end
      end
    end
  end
end
