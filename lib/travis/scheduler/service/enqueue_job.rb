
module Travis
  module Scheduler
    module Service
      class EnqueueJob < Struct.new(:context, :job, :opts)
        include Service, Registry

        register :service, :enqueue_job

        MSGS = {
          queueing: 'enqueueing job %s (%s)',
          redirect: 'Found job.queue: %s. Redirecting to: %s'
        }

        def run
          transaction do
            info MSGS[:queueing] % [job.id, repo.slug]
            set_queued
            notify
          end
        end

        private

          def set_queued
            job.update_attributes!(state: :queued, queued_at: Time.now.utc)
          end

          def notify
            async :notify, job: { id: job.id }
          end

          def repo
            job.repository
          end

          def jid
            opts[:jid]
          end

          def transaction(&block)
            ActiveRecord::Base.transaction(&block)
          end
      end
    end
  end
end
