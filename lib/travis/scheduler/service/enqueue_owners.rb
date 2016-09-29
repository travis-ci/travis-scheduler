require 'forwardable'
require 'travis/scheduler/limit/jobs'
require 'travis/scheduler/model/owners'

module Travis
  module Scheduler
    module Service
      class EnqueueOwners < Struct.new(:context, :data, :opts)
        include Service, Registry
        extend Forwardable

        register :service, :enqueue_owners

        MSGS = {
          schedule: 'Evaluating jobs for owner group: %s'
        }

        def_delegators :limit, :reports, :jobs

        def run
          info MSGS[:schedule] % [owners.logins.join(', ')]
          collect
          report
          enqueue
        end
        with :exclusive

        private

          def collect
            limit.run
          end

          def report
            reports.each { |line| info line }
          end

          def enqueue
            jobs.each { |job| inline :enqueue_job, job, jid: jid }
          end

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
            opts[:jid]
          end
      end
    end
  end
end
