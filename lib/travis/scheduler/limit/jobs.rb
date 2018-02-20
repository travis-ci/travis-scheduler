require 'travis/scheduler/helper/context'
require 'travis/scheduler/helper/metrics'

module Travis
  module Scheduler
    module Limit
      MSGS = {
        max:       'max jobs for %s by %s: %s',
        max_plan:  'max jobs for %s by %s: %s (%s)',
        max_stage: 'jobs for %s limited at stage: %s (queueable: %s)',
        summary:   '%s: total: %s, running: %s, queueable: %s',
        stats:     'jobs waiting for %s: %s'
      }

      class Jobs < Struct.new(:context, :owners)
        require 'travis/scheduler/limit/by_owner'
        require 'travis/scheduler/limit/by_queue'
        require 'travis/scheduler/limit/by_repo'
        require 'travis/scheduler/limit/by_stage'
        require 'travis/scheduler/limit/state'

        include Helper::Context, Helper::Metrics

        LIMITS = [ByOwner, ByRepo, ByQueue, ByStage]

        def run
          unleak_queueables if ENV['UNLEAK_QUEUEABLE_JOBS']
          check_all
          report summary
          report stats if waiting.any?
          honeycomb
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
                WHERE jobs.state <> 'created' AND #{Job.owned_by(owners.all).to_sql}
              )
            sql
          rescue => e
            puts e.message
          end
          time :unleak_queueables, key: 'scheduler.unleak_queueables'

          # We run each queueable job through a series of limits and select it
          # only if all limits have allowed the job through by returning true.
          # I.e. if any limit returns false then the given job will not be
          # selected for queueing.
          def check_all
            queueable.each do |job|
              if enqueue?(job)
                selected << job
              end
            end
          end

          def set_queue(job)
            inline :set_queue, job
          end

          def enqueue?(job)
            limits_for(job).map(&:enqueue?).inject(&:&)
          end

          def limits_for(job)
            LIMITS.map { |limit| limit.new(context, reports, owners, job, selected, state, config) }
          end

          def summary
            MSGS[:summary] % [owners.to_s, queueable.size, state.running_by_owners, selected.size]
          end

          def stats
            jobs = waiting.group_by(&:repository)
            stats = jobs.map { |repo, jobs| [repo.slug, jobs.size].join('=') }
            MSGS[:stats] % [owners.key, stats.join(', ')]
          end

          def honeycomb
            Travis::Honeycomb.context.add('scheduler.stats', {
              running: state.running_by_owners,
              enqueued: selected.size,
              waiting: waiting.size,
              concurrent: selected.size + state.running_by_owners,
            })
          end

          def report(*reports)
            self.reports.concat(reports).uniq!
          end

          def waiting
            queueable - selected
          end

          def queueable
            @queueable ||= Job.by_owners(owners.all).queueable.to_a
          end
          time :queueable, key: 'scheduler.queueable_jobs'

          def state
            @state ||= State.new(owners, config)
          end
      end
    end
  end
end
