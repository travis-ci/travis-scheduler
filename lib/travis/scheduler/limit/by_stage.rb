require 'travis/scheduler/helper/context'
require 'travis/stages'

module Travis
  module Scheduler
    module Limit
      class ByStage < Struct.new(:context, :owners, :job, :queued, :state, :config)
        include Helper::Context

        def enqueue?
          return true unless job.stage
          !!report if queueable?
        end

        def reports
          @reports ||= []
        end

        private

          def queueable?
            queueable = Stages.build(jobs).startable
            queueable.map { |attrs| attrs[:id] }.include?(job.id)
          end

          ATTRS = [:id, :state, :stage]

          def jobs
            @jobs ||= begin
              # TODO would it make sense to cache these on `state`?
              scope = Job.where(source_id: job.source_id).order(:stage)
              scope.pluck(*ATTRS).map { |values| ATTRS.zip(values).to_h }
            end
          end

          def stages
            jobs.map { |job| job[:stage] }
          end

          def report
            reports << MSGS[:max_stage] % ["build #{job.source_id}", stages.first.split('.').first]
          end
      end
    end
  end
end
