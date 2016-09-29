require 'travis/scheduler/limit'
require 'travis/scheduler/model/owners'

module Travis
  module Scheduler
    module Service
      class EnqueueOwners < Struct.new(:context, :attrs)
        include Service, Registry

        register :service, :enqueue_owners

        MSGS = {
          schedule: 'Evaluating jobs for owner group: %s'
        }

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
            limit.reports.each { |line| info line }
          end

          def enqueue
            limit.queueable.each do |job|
              inline :enqueue_job, job
            end
          end

          def limit
            @limit ||= Limit.new(context, owners)
          end

          def owners
            @owners ||= Model::Owners.new(attrs, config)
          end

          def exclusive(&block)
            super(['scheduler.owners', owners.key].join('-'), config, &block)
          end
      end
    end
  end
end
