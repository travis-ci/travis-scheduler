module Travis
  module Scheduler
    module Jobs
      module Capacity
        class Base < Struct.new(:context, :owners, :capacities)
          def reduce(count)
            @reduced = count
            [count - max, 0].max.tap do |rest|
              # p [self.class.name.split('::').last, max, count, rest]
            end
          end

          def reduce(jobs)
            @reduced = [max, jobs.size].min
            # p [self.class.name.split('::').last, max, jobs.size, reduced]
            jobs[@reduced..-1]
          end

          def accept?(job)
            exhausted? ? reject(job) : accept(job)
          end

          def exhausted?
            # p [self.class.name.split('::').last, :exhausted?, accepted.size, max, reduced, max - reduced, accepted.size >= max - reduced]
            accepted.size >= max - reduced
          end

          def reports
            accepted + rejected
          end

          def accepted
            @accepted ||= []
          end

          def rejected
            @rejected ||= []
          end

          def to_s
            "#{self.class.name.split('::').last.downcase} max=#{max}"
          end

          private

            def reduced
              @reduced.to_i
            end

            def running
              capacities.jobs.running
            end

            def selected
              capacities.accepted.size
            end

            def accept(job)
              accepted << report(:accept, job) if max > 0
              true
            end

            def reject(job)
              rejected << report(:reject, job) if max > 0
              false
            end

            def report(status, job)
              {
                type: :capacity,
                name: self.class.name.split('::').last.underscore.to_sym,
                status: status,
                owner: owners.to_s,
                id: job.id,
                repo_id: job.repository_id,
                reduced: reduced.to_i
              }
            end

            def config
              context.config
            end
        end
      end
    end
  end
end
