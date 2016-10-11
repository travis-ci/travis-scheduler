require 'forwardable'
require 'travis/scheduler/limit/jobs'
require 'travis/scheduler/model/owners'

module Travis
  module Scheduler
    module Service
      class EnqueueOwners < Struct.new(:context, :data)
        include Registry, Helper::Context, Helper::Locking, Helper::Logging,
          Helper::Metrics, Helper::Runner, Helper::With
        extend Forwardable

        register :service, :enqueue_owners

        MSGS = {
          schedule: 'Evaluating jobs for owner group: %s'
        }

        def_delegators :limit, :reports, :jobs

        def run
          info MSGS[:schedule] % [owners.to_s]
          collect
          report
          enqueue
        end
        with :exclusive

        private

          def collect
            limit.run
          end
          time :collect

          def report
            reports.each { |line| info line }
          end

          def enqueue
            jobs.each { |job| inline :enqueue_job, job, jid: jid }
          end
          time :enqueue

          def limit
            @limit ||= Limit::Jobs.new(context, owners)
          end

          def owners
            @owners ||= Model::Owners.new(data, config)
          end

          def exclusive(&block)
            super(['scheduler.owners', owners.key].join('-'), config, &block)
          end

          def jid
            data[:jid]
          end

          def src
            data[:src]
          end

          def opts
            super || {}
          end
      end
    end
  end
end
