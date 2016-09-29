require 'travis/scheduler/serialize/live'
require 'travis/scheduler/serialize/worker'

module Travis
  module Scheduler
    module Services
      class Notify < Struct.new(:context, :data)
        include Registry, Helper::Context, Helper::Locking, Helper::Logging,
          Helper::Metrics, Helper::Runner, Helper::With

        register :service, :notify

        MSGS = {
          redirect: 'Found job.queue: %s. Redirecting to: %s'
        }

        def run
          # fail('kaputt. testing exception tracking.') if job.repository.owner_name == 'svenfuchs'
          info "Publishing worker payload for job=#{job.id} queue=#{job.queue}"
          redirect_queue
          publish
          notify_live
        end

        private

          def publish
            Metriks.timer('enqueue.publish_job').time do
              publisher.publish(payload, properties: { type: 'test', persistent: true })
            end
          end
          time :collect

          def payload
            Metriks.timer('enqueue.build_worker_payload').time do
              Serialize::Worker.new(job, config).data
            end
          end
          time :collect

          def publisher
            Amqp::Publisher.new(job.queue)
          end

          def notify_live
            Live.push(Serialize::Live.new(job).data, event: 'job:queued')
          end

          def job
            @job ||= Job.find(job_id)
          end

          def job_id
            data[:job] && data[:job][:id] or fail("No job id given: #{data}")
          end

          def redirect_queue
            queue = redirections[job.queue] or return
            info MSGS[:redirect] % [job.queue, queue]
            job.update_attributes!(queue: queue)
          end

          def redirections
            config.queue_redirections || {}
          end

          def jid
            data[:jid]
          end
      end
    end
  end
end
