require 'coder'
require 'travis/scheduler/serialize/live'
require 'travis/scheduler/serialize/worker'

module Travis
  module Scheduler
    module Service
      class Notify < Struct.new(:context, :data)
        include Registry, Helper::Context, Helper::Logging, Helper::Metrics,
          Helper::Runner

        register :service, :notify

        def run
          # fail('kaputt. testing exception tracking.') if job.repository.owner_name == 'svenfuchs'
          set_queue
          notify_workers
          notify_live
        end

        private

          def set_queue
            inline :set_queue, job, jid: jid, src: src
          end

          def notify_workers
            info "Publishing worker payload for job=#{job.id} queue=#{job.queue}"
            amqp.publish(worker_payload, properties: { type: 'test', persistent: true })
          end

          def notify_live
            Live.push(live_payload, event: 'job:queued')
          end

          def worker_payload
            deep_clean(Serialize::Worker.new(job, config).data)
          end
          time :worker_payload

          def live_payload
            Serialize::Live.new(job).data
          end
          time :live_payload

          def job
            @job ||= Job.find(job_id)
          end

          def job_id
            data[:job] && data[:job][:id] or fail("No job id given: #{data}")
          end

          def amqp
            Amqp::Publisher.new(job.queue)
          end

          def jid
            data[:jid]
          end

          def src
            data[:src]
          end

          def deep_clean(obj)
            case obj
            when ::Hash, Hashr
              obj.to_h.map { |key, value| [key, deep_clean(value)] }.to_h
            when Array
              obj.map { |obj| deep_clean(obj) }
            when String
              ::Coder.clean(obj)
            else
              obj
            end
          end
      end
    end
  end
end
