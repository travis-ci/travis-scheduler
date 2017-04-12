require 'travis/scheduler/helper/context'

module Travis
  module Scheduler
    module Limit
      MSGS = {
        max:       'max jobs for %s by %s: %s',
        max_plan:  'max jobs for %s by %s: %s (%s)',
        max_stage: 'jobs for %s limited at stage: %s (queueable: %s)',
        summary:   '%s: total: %s, running: %s, queueable: %s'
      }

      class Jobs < Struct.new(:context, :owners)
        require 'travis/scheduler/limit/by_owner'
        require 'travis/scheduler/limit/by_queue'
        require 'travis/scheduler/limit/by_repo'
        require 'travis/scheduler/limit/by_stage'
        require 'travis/scheduler/limit/state'

        include Helper::Context

        LIMITS = [ByOwner, ByRepo, ByQueue, ByStage]

        def run
          # unleak_queueables
          check_all
          report summary
        end

        def reports
          @reports ||= []
        end

        def selected
          @selected ||= []
        end

        private

          def unleak_queueables
            Queueable.connection.execute <<~sql
              DELETE FROM queueable_jobs
              WHERE id IN (
                SELECT queueable_jobs.id
                FROM queueable_jobs
                JOIN jobs ON queueable_jobs.job_id = jobs.id
                WHERE jobs.state <> 'created'
              )
            sql
          rescue => e
            puts e.message
          end

          def check_all
            queueable.each do |job|
              case check(job)
              when :limited
                break
              when true
                selected << job
              end
            end
          end

          def set_queue(job)
            inline :set_queue, job
          end

          def check(job)
            catch(:result) { enqueue?(job) }
          end

          def enqueue?(job)
            limits_for(job).map do |limit|
              result = limit.enqueue?
              report *limit.reports
              result
            end.inject(&:&)
          end

          def limits_for(job)
            LIMITS.map { |limit| limit.new(context, owners, job, selected, state, config) }
          end

          def summary
            MSGS[:summary] % [owners.to_s, queueable.size, state.running_by_owners, selected.size]
          end

          def report(*reports)
            self.reports.concat(reports).uniq!
          end

          def queueable
            @queueable ||= Job.by_owners(owners.all).queueable.to_a
          end

          def state
            @state ||= State.new(owners, config)
          end
      end
    end
  end
end
