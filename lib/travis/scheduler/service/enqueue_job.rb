module Travis
  module Scheduler
    module Service
      class EnqueueJob < Struct.new(:context, :job, :opts)
        include Registry, Helper::Context, Helper::Honeycomb, Helper::Locking,
          Helper::Logging, Helper::Metrics, Helper::Runner, Helper::With

        register :service, :enqueue_job

        MSGS = {
          queueing: 'enqueueing job %s (%s)',
          redirect: 'Found job.queue: %s. Redirecting to: %s'
        }

        def run
          info MSGS[:queueing] % [job.id, repo.slug]
          set_queued
          notify
        end
        with :run, :honeycomb

        private

          def set_queued
            puts "EnqueueJob: About to put the job in a queue #{job.inspect}"
            puts "EnqueueJob: About to put the job in a queue #{job.stage}"
            puts "EnqueueJob: About to put the job in a queue #{job.stage.try(:build)}"
            job.update!(state: :queued, queued_at: Time.now.utc)
            job.queueable = false
          end
          with :set_queued, :transaction

          def notify
            async :notify, job: { id: job.id }, jid: jid
          end

          def repo
            job.repository
          end

          def waited
            Time.now.utc - Time.at(job.received_at ? job.updated_at : job.created_at)
          end

          def honeycomb(&block)
            super(job_id: job.id, repo_slug: repo.slug, job_waiting_s: waited)
            yield
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
