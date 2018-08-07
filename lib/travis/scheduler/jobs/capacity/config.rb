module Travis
  module Scheduler
    module Jobs
      module Capacity
        # what does config mean with regards to paid/free capacity? do we need
        # richer config format? or can we get rid of it on com?
        class Config < Base
          def applicable?
            owners.logins.any? { |login| max_for(login) }
          end

          def report(status, job)
            super.merge(max: max)
          end

          private

            def max
              @max ||= owners.logins.map { |login| max_for(login).to_i }.inject(&:+)
            end

            def max_for(login)
              config[:limit][:by_owner][login.to_sym]
            end
        end
      end
    end
  end
end
