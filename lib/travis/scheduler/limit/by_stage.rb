require 'travis/scheduler/helper/context'
require 'travis/scheduler/model/stages'

module Travis
  module Scheduler
    module Limit
      class ByStage < Struct.new(:context, :owners, :job, :queued, :state, :config)
        include Helper::Context

        def enqueue?
          return true unless job.stage_number
          !!report if queueable?
        end

        def reports
          @reports ||= []
        end

        private

          def queueable?
            queueable.map { |attrs| attrs[:id] }.include?(job.id)
          end

          def queueable
            @queueable ||= Stages.build(jobs).startable
          end

          ATTRS = [:id, :state, :stage_number]
          KEYS  = [:id, :state, :stage]

          def jobs
            @jobs ||= begin
              # TODO would it make sense to cache these on `state`?
              jobs = Job.where(source_id: job.source_id)
              sort(jobs).map { |job| attrs(job) }
            end
          end

          def attrs(job)
            {
              id:    job.id,
              stage: job.stage_number,
              state: job.finished? ? :finished : :created
            }
          end

          def sort(jobs)
            num = ->(job) { job.stage_number.split('.').map(&:to_i) }
            jobs.sort { |lft, rgt| num.(lft) <=> num.(rgt) }
          end

          def stages
            jobs.map { |job| job[:stage] }
          end

          def report
            reports << MSGS[:max_stage] % ["build #{job.source_id}", job.stage.number, queueable.size]
          end
      end
    end
  end
end
