module Travis
  module Scheduler
    module Service
      class EnqueueJob < Struct.new(:context, :job, :opts)
        include Registry, Helper::Context, Helper::Locking, Helper::Logging,
          Helper::Metrics, Helper::Runner, Helper::With

        register :service, :enqueue_job

        MSGS = {
          queueing: 'enqueueing job %s (%s)',
          redirect: 'Found job.queue: %s. Redirecting to: %s'
        }

        def run
          info MSGS[:queueing] % [job.id, repo.slug]
          Travis::Honeycomb.context.add('job_id', job.id)
          Travis::Honeycomb.context.add('repo_slug', repo.slug)
          set_queued
          notify
        end

        private

          def set_queued
            transaction do
              job.update_attributes!(state: :queued, queued_at: Time.now.utc)
              job.queueable = false
            end
          end

          def notify
            async :notify, job: { id: job.id }, jid: jid
          end

          def repo
            job.repository
          end

          def jid
            opts[:jid]
          end

          def src
            opts[:src]
          end

          def transaction(&block)
            ActiveRecord::Base.transaction(&block)
          end
      end
    end
  end
end
