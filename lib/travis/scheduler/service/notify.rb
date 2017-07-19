require 'travis/scheduler/helper/coder'
require 'travis/scheduler/serialize/live'
require 'travis/scheduler/serialize/worker'

module Travis
  module Scheduler
    module Service
      class Notify < Struct.new(:context, :data)
        include Registry, Helper::Coder, Helper::Context, Helper::Logging,
          Helper::Metrics, Helper::Runner

        register :service, :notify

        MSGS = {
          publish:  'Publishing worker payload for job id=%s queue=%s to %s.',
          redirect: 'Found job.queue: %s. Redirecting to: %s.'
        }

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
            rollout? ? notify_job_board : notify_rabbitmq
          end

          def notify_job_board
            info :publish, job.id, job.queue, 'job board'
            JobBoard.post(job.id, worker_payload)
          end

          def notify_rabbitmq
            info :publish, job.id, job.queue, 'rabbitmq'
            amqp.publish(worker_payload, properties: { type: 'test', persistent: true })
          end

          def notify_live
            Live.push(live_payload, live_params)
          end

          def rollout?
            Rollout.matches?(:job_board, uid: owner.id, owner: owner.login, redis: redis)
          end

          def worker_payload
            deep_clean(Serialize::Worker.new(job, config).data)
          end
          time :worker_payload

          def live_payload
            Serialize::Live.new(job).data
          end
          time :live_payload

          def live_params
            params = { event: 'job:queued' }
            uid = "#{job.repository.owner_id}-#{job.repository.owner_type[0]}"
            if Rollout.matches?('user-channel', redis: redis, uid: uid)
              params[:user_ids] = user_ids
            end
            params
          end
          time :live_params

          def user_ids
            job.repository.permissions.pluck(:user_id)
          end

          def owner
            job.owner
          end

          def job
            @job ||= Job.find(job_id)
          end

          def job_id
            data[:job] && data[:job][:id] or fail("No job id given: #{data}")
          end

          def amqp
            Amqp::Publisher.new(job.queue)
          end

          def redirect_queue
            queue = redirections[job.queue] or return
            info MSGS[:redirect] % [job.queue, queue]
            job.update_attributes!(queue: queue)
          end

          def redirections
            config[:queue_redirections] || {}
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
      end
    end
  end
end
