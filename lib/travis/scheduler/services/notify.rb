require 'travis/support/registry'

module Travis
  module Scheduler
    module Services
      class Notify < Struct.new(:data)
        include Registry

        register :service, :notify

        def run
          p job.repository.owner_name
          fail('kaputt. testing exception tracking.') if job.repository.owner_name == 'svenfuchs'
          info "Publishing worker payload for job=#{job.id} queue=#{job.queue}."
          publish
        end

        private

          def publish
            Metriks.timer('enqueue.publish_job').time do
              publisher.publish(payload, properties: { type: "test", persistent: true })
            end
          end

          def payload
            Metriks.timer('enqueue.build_worker_payload').time do
              Payloads::Worker.new(job).data
            end
          end

          def publisher
            Amqp::Publisher.builds(job.queue)
          end

          def job
            @job ||= Job.find(job_id)
          end

          def job_id
            data[:job] && data[:job][:id] || fail("No job id given: #{data}")
          end

          def info(msg)
            Scheduler.logger.info(msg)
          end
      end
    end
  end
end
