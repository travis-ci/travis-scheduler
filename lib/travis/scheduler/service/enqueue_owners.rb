require 'travis/rollout'
require 'travis/scheduler/limit/jobs'
require 'travis/owners'

module Travis
  module Scheduler
    module Service
      class EnqueueOwners < Struct.new(:context, :data)
        include Registry, Helper::Context, Helper::Locking, Helper::Logging,
          Helper::Memoize, Helper::Metrics, Helper::Runner, Helper::With
        extend Forwardable

        register :service, :enqueue_owners

        MSGS = {
          schedule: 'Evaluating jobs for owner group: %s'
        }

        def run
          info MSGS[:schedule] % [owners.to_s]
          Travis::Honeycomb.context.add('owner_group', owners.key)
          collect
          report
          enqueue
        end
        with :run, :exclusive

        private

          def collect
            limit.run
          end
          time :collect

          def report
            limit.reports.each { |line| info line }
          end

          def enqueue
            jobs = limit.selected
            jobs = jobs.partition { |job| !job.allow_failure }
            jobs.flatten.each { |job| inline :enqueue_job, job, jid: jid, meta: meta }
          end
          time :enqueue

          def limit
            if jobs?
              Jobs::Select.new(context, owners)
            else
              Limit::Jobs.new(context, owners)
            end
          end
          memoize :limit

          def jobs?
            owners.any? do |owner|
              Rollout.matches?(:jobs, uid: owner.uid, owner: owner.login)
            end
          end

          def owners
            @owners ||= Owners.group(data, config.to_h)
          end

          def exclusive(&block)
            super(['scheduler.owners', owners.key].join('-'), config.to_h, retries: 0, &block)
          rescue Owners::ArgumentError => e
            error e.message
          end

          def jid
            data[:jid]
          end

          def src
            data[:src]
          end

          def meta
            data[:meta] || {}
          end

          def opts
            super || {}
          end
      end
    end
  end
end
