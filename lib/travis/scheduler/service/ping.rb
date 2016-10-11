module Travis
  module Scheduler
    module Services
      class Ping < Struct.new(:context, :data)
        include Registry, Helper::Context, Helper::Locking, Helper::Logging,
          Helper::Metrics, Helper::Runner

        register :service, :ping

        MSGS = {
          start: 'Found %s owners to ping.'
        }

        def run
          info MSGS[:start] % owners.size
          ping
        end

        private

          def ping
            owners.each do |owner_id, owner_type|
              async :enqueue_owners, owner_id: owner_id.to_i, owner_type: owner_type, src: :ping
            end
          end

          def owners
            @owners ||= begin
              scope = Job.where(state: :created).where('created_at <= ?', Time.now - 2 * 60)
              scope = scope.distinct
              scope = scope.select(:owner_type, :owner_id)
              scope.map { |job| [job.owner_id, job.owner_type] }.uniq
            end
          end

          def jid
            data && data[:jid]
          end
      end
    end
  end
end
