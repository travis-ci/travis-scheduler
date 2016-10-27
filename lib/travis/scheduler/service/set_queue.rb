module Travis
  module Scheduler
    module Service
      class SetQueue < Struct.new(:context, :job, :opts)
        include Registry, Helper::Context, Helper::Logging

        register :service, :set_queue

        MSGS = {
          redirect: 'Found job.queue: %s. Redirecting to: %s',
          queue:    'Setting queue to %s for job=%s'
        }

        def run
          info MSGS[:queue] % [queue, job.id]
          job.update_attributes!(queue: queue)
        end

        private

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
