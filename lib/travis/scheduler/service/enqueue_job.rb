require 'travis/scheduler/helper/logging'
require 'travis/scheduler/helper/locking'
require 'travis/scheduler/helper/runner'
require 'travis/scheduler/helper/with'
require 'travis/support/registry'

module Travis
  module Scheduler
    module Service
      class EnqueueJob < Struct.new(:job, :config)
        include Logging, Locking, Registry, Runner, With

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

          def redirect_queue
            return unless queue = redirections[job.queue]
            info MSGS[:redirect] % [job.queue, queue]
            job.queue = queue
            job.save!
          end

          def redirections
            Travis::Scheduler.config.queue_redirections
          end

          def transaction(&block)
            ActiveRecord::Base.transaction(&block)
          end
      end
    end
  end
end
