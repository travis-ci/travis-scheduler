require 'travis/scheduler/helper/context'
require 'travis/scheduler/helper/metrics'
require 'travis/support/filter_migrated_jobs'

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
        include FilterMigratedJobs

        LIMITS = [ByOwner, ByRepo, ByQueue, ByStage]
        attr_reader :waiting_by_owner

        def run
          unleak_queueables if ENV['UNLEAK_QUEUEABLE_JOBS']
          @waiting_by_owner = 0
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
            queueable.each_with_index do |job, index|
              case check(job)
              when :limited
                # The rest of the jobs will definitely be waiting for
                # concurrency, regardless of other limits that might apply
                @waiting_by_owner += queueable.length - index
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
            limits = limits_for(job).map(&:enqueue?)
            if !limits[0]
              @waiting_by_owner += 1
            end
            limits.inject(&:&)
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
              waiting_for_concurrency: @waiting_by_owner,
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
            @queueable ||= begin
              filter_migrated_jobs(Job.by_owners(owners.all).queueable.to_a)
            end
          end
          time :queueable, key: 'scheduler.queueable_jobs'

          def state
            @state ||= State.new(owners, config)
          end
      end
    end
  end
end
