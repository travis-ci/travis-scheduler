module Travis
  module Scheduler
    module Service
      class Ping < Struct.new(:context, :data)
        include Registry, Helper::Context, Helper::Locking, Helper::Logging,
          Helper::Metrics, Helper::Runner

        register :service, :ping

        MSGS = {
          start: 'Found %s owners to ping.'
        }

        def run
          info MSGS[:start] % count
          ping
        end

        private

          def ping
            owners.each.with_index do |(owner_id, owner_type), ix|
              async :enqueue_owners, owner_id: owner_id.to_i, owner_type: owner_type, src: :ping, at: at(ix).to_f
            end
          end

          def owners
            @owners ||= begin
              scope = Job.column_names.include?('queueable') ? Job.where(queueable: true) : Job.where(state: :created)
              scope = scope.where('created_at <= ?', Time.now - interval)
              scope = scope.distinct
              scope = scope.select(:owner_type, :owner_id)
              scope.map { |job| [job.owner_id, job.owner_type] }.uniq
            end
          end

          def at(ix)
            now + ix * step
          end

          def now
            @now ||= Time.now
          end

          def step
            count > interval ? interval / count : 1
          end

          def count
            owners.size
          end

          def interval
            config[:ping][:interval]
          end

          def jid
            data[:jid]
          end

          def src
            data[:src]
          end

          def data
            super || {}
          end
      end
    end
  end
end
