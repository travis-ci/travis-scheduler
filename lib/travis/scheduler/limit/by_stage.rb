require 'travis/scheduler/helper/context'
require 'travis/scheduler/model/stages'

module Travis
  module Scheduler
    module Limit
      class ByStage < Struct.new(:context, :reports, :owners, :job, :queued, :state, :config)
        include Helper::Context

        def enqueue?
          return true unless job.stage_number
          !!report if queueable?
        end

        private

          def queueable?
            queueable.map { |attrs| attrs[:id] }.include?(job.id)
          end

          def queueable
            @queueable ||= Stages.build(state.jobs_by_source(job.source_id)).startable
          end

          ATTRS = [:id, :state, :stage_number]
          KEYS  = [:id, :state, :stage]

          def attrs(job)
            {
              id:    job.id,
              stage: job.stage_number,
              state: job.finished? ? :finished : :created
            }
          end

          def stages
            state.jobs.map { |job| job[:stage] }
          end

          def report
            reports << MSGS[:max_stage] % ["build id=#{job.source_id} repo=#{job.repository.slug}", job.stage.number, queueable.size]
          end
      end
    end
  end
end
