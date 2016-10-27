module Travis
  module Scheduler
    module Service
      class SetQueue < Struct.new(:context, :job, :opts)
        include Registry, Helper::Context, Helper::Logging

        register :service, :set_queue

        MSGS = {
          # redirect: 'Found job.queue: %s. Redirecting to: %s'
          check: 'Queue selection evaluated to %s, but the current queue is %s for job=%s',
          queue: 'Setting queue to %s for job=%s'
        }

        def run
          check
          set if set?
        end

        private

          def check
            warn MSGS[:check] % [queue, job.queue, job.id] unless queue == job.queue
          end

          def set?
            return true if ENV['QUEUE_SELECTION']
            return false unless owners = ENV['QUEUE_SELECTION_OWNERS']
            owners = owners.split(',')
            owners.include?(job.owner.login)
          end

          def set
            info MSGS[:queue] % [queue, job.id]
            job.update_attributes!(queue: queue)
          end

          def queue
            @queue ||= redirect(Queue.new(job, config, logger).select)
          end

          # TODO confirm we don't need queue redirection any more
          def redirect(queue)
            redirect = redirections[queue]
            info MSGS[:redirect] % [queue, redirect] if redirect
            redirect || queue
          end

          def redirections
            config[:queue_redirections] || {}
          end

          def jid
            opts[:jid]
          end

          def src
            opts[:src]
          end

          def data
            super || {}
          end
      end
    end
  end
end
