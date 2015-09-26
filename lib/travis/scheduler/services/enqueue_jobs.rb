require 'travis/support/exceptions/handling'
require 'travis/scheduler/helpers/benchmark'
require 'travis/scheduler/helpers/live'
require 'travis/scheduler/models/organization'
require 'travis/scheduler/models/user'
require 'travis/scheduler/payloads/worker'
require 'travis/scheduler/services/limit/default'
require 'travis/scheduler/services/limit/configurable'

module Travis
  module Scheduler
    module Services
      # Finds owners that have queueable jobs and for each owner:
      #
      #   * checks how many jobs can be enqueued
      #   * finds the oldest N queueable jobs and
      #   * enqueues them
      class EnqueueJobs
        TIMEOUT = 2

        extend Travis::Exceptions::Handling
        include Helpers::Benchmark, Helpers::Live

        def self.run
          new.run
        end

        def reports
          @reports ||= {}
        end

        def run
          benchmark 'enqueue jobs' do
            enqueue_all
            Travis.logger.info(format_reports(reports))
          end
        end
        rescues :run, from: Exception, backtrace: false

        private

          def strategy
            Limit.const_get(Travis.config.limit.strategy.camelize)
          end

          def enqueue_all
            grouped_jobs = jobs.group_by(&:owner)

            Metriks.timer('enqueue.total').time do
              grouped_jobs.each do |owner, jobs|
                next unless owner
                Metriks.timer('enqueue.full_enqueue_per_owner').time do
                  enqueue_owner(owner, jobs)
                end
              end
            end
          end

          def enqueue_owner(owner, jobs)
            limit = nil
            queueable = nil

            Metriks.timer('enqueue.limit_per_owner').time do
              limit = strategy.new(owner, jobs)
              Travis.logger.info "About to evaluate jobs for: #{owner.login}."
              queueable = limit.queueable
            end

            Metriks.timer('enqueue.enqueue_per_owner').time do
              enqueue(queueable)
            end

            Metriks.timer('enqueue.report_per_owner').time do
              reports[owner.login] = limit.report
            end
          rescue => e
            Travis.logger.error("[alert] Unable to evaluate jobs for owner #{owner.login}. Job ids: #{jobs.map(&:id)}")
            Travis::Exceptions.handle(e)
          end

          def enqueue(jobs)
            jobs.each do |job|
              Travis.logger.info("enqueueing slug=#{job.repository.slug} job_id=#{job.id}")
              Metriks.timer('enqueue.publish_job').time do
                publish(job)
              end

              Metriks.timer('enqueue.enqueue_job').time do
                job.update_attributes!(state: :queued, queued_at: Time.now.utc)
                notify_live(job)
              end
            end
          end

          def publish(job)
            Metriks.timer('enqueue.publish_job').time do
              # check the properties are being set correctly,
              # and type is being used
              publisher(job.queue).publish(payload(job), properties: { type: "test", persistent: true })
            end
          end

          def payload(job)
            Payloads::Worker.new(job).data
          rescue => e
            # TODO this would ideally error the job
            Travis.logger.error("[alert] Unable to generate worker payload for job #{job.id}.")
            Travis::Exceptions.handle(e)
          end

          def jobs
            Metriks.timer('enqueue.fetch_jobs').time do
              jobs = Job.includes(:owner, :commit, repository: :key, source: :request).queueable.all
              Travis.logger.info "Found #{jobs.size} jobs in total." if jobs.size > 0
              jobs
            end
          end

          def publisher(queue)
            Travis::Amqp::Publisher.builds(queue)
          end

          def format_reports(reports)
            reports = Array(reports)
            if reports.any?
              reports = reports.map do |repo, report|
                "  #{repo}: #{report.map { |key, value| "#{key}: #{value}" }.join(', ')}"
              end
              "enqueued:\n#{reports.join("\n")}"
            else
              'nothing to enqueue.'
            end
          end
      end
    end
  end
end
