# frozen_string_literal: true

module Travis
  module Scheduler
    module Service
      class SetQueue < Struct.new(:context, :job, :opts)
        include Helper::Logging
        include Helper::Context
        include Registry

        register :service, :set_queue

        MSGS = {
          redirect: 'Found job.queue: %s. Redirecting to: %s',
          queue: 'Setting queue to %s for job=%s',
          canceled: 'Build %s has been canceled, job %s being canceled'
        }.freeze

        def run
          info format(MSGS[:queue], queue, job.id)
          job.update!(queue:)
        end

        private

        def queue
          if job.stage.present? && job.stage.state == "canceled"
              info MSGS[:canceled] % [job.source.id, job.id]
              payload = { id: job.id, source: 'scheduler' }
              Hub.push('job:cancel', payload)
            else
              @queue ||= redirect(Queue.new(job, config, logger).select)
            end
          rescue => e
            puts "ERROR while trying to queue: #{e.message}"
            puts "Backtrace:"
            puts e.backtrace.join("\n")
            @queue ||= redirect(Queue.new(job, config, logger).select)
        end

        # TODO: confirm we don't need queue redirection any more
        def redirect(queue)
          redirect = redirections[queue]
          info format(MSGS[:redirect], queue, redirect) if redirect
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
