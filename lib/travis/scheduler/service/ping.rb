module Travis
  module Scheduler
    module Services
      class Ping < Struct.new(:context, :data)
        include Registry, Helper::Context, Helper::Locking, Helper::Logging,
          Helper::Metrics, Helper::Runner

        QUERY = %(SELECT DISTINCT owner_id, owner_type FROM jobs WHERE state = 'created')

        register :service, :ping

        MSGS = {
          start: 'Pinging all owners'
        }

        def run
          info MSGS[:start]
          ping
        end

        private

          def ping
            owners.each do |id, type|
              async :enqueue_owners, owner_id: id.to_i, owner_type: type
            end
          end

          def owners
            ActiveRecord::Base.connection.select_rows(QUERY)
          end

          def jid
            data && data[:jid]
          end
      end
    end
  end
end
