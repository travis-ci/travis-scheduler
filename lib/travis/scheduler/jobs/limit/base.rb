module Travis
  module Scheduler
    module Jobs
      module Limit
        class Base < Struct.new(:context, :owners, :state)
          def accept?(job)
            limit?(job) ? reject(job) : accept(job)
          end

          def reports
            accepted + rejected
          end

          private

          def limit?(job)
            accepted.size + running(job) >= max(job)
          end

          def accept(job)
            accepted << report(:accept, job)
            true
          end

          def reject(job)
            rejected << report(:reject, job)
            false
          end

          def accepted
            @accepted ||= []
          end

          def rejected
            @rejected ||= []
          end
        end
      end
    end
  end
end
