module Travis
  module Scheduler
    module Service
      class SetQueue < Struct.new(:context, :job, :opts)
        include Registry, Helper::Context, Helper::Logging

        register :service, :set_queue

        MSGS = {
          redirect: 'Found job.queue: %s. Redirecting to: %s',
          queue:    'Setting queue to %s for job=%s',
          canceled: 'Build %s has been canceled, job %s being canceled'
        }

        def run
          info MSGS[:queue] % [queue, job.id]
          job.update!(queue: queue)
        end

        private

          def queue
            puts "the state of stage is #{job.stage.inspect}"
            puts "the state of stage is being reloaded"
            job.stage.reload
            puts "the state of stage is #{job.stage.inspect}"


            if  job.stage.state == "canceled"
              info MSGS[:canceled] % [job.source.id, job.id]
              payload = { id: job.id, source: 'scheduler' }
              Hub.push('job:cancel', payload)
              # binding.pry
              # stop other jobs from being queued
              job_ids = Job.where(source_id: job.source_id).ids
              Queueable.where(job_id: job_ids).delete_all

              # payload = { id: job.source.id, source: 'scheduler' }
              # Hub.push('build:cancel', payload)
            else
              @queue ||= redirect(Queue.new(job, config, logger).select)
            end
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
