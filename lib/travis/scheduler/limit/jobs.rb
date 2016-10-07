require 'travis/scheduler/helper/context'

module Travis
  module Scheduler
    module Limit
      MSGS = {
        max:      'max jobs for %s by %s: %s',
        max_plan: 'max jobs for %s by %s: %s (%s)',
        summary:  '%s: total: %s, running: %s, queueable: %s'
      }

      class Jobs < Struct.new(:context, :owners)
        require 'travis/scheduler/limit/by_owner'
        require 'travis/scheduler/limit/by_repo'
        require 'travis/scheduler/limit/state'

        include Helper::Context

        LIMITS = [ByOwner, ByRepo]

        def run
          check_all
          report summary
        end

        def reports
          @reports ||= []
        end

        def jobs
          @jobs ||= []
        end

        private

          def check_all
            queueable.each do |job|
              case check(job)
              when :limited
                break
              when true
                jobs << job
              end
            end
          end

          def check(job)
            catch(:result) { enqueue?(job) }
          end

          def enqueue?(job)
            limits_for(job).map do |limit|
              result = limit.enqueue?
              report *limit.reports
              result
            end.inject(&:&)
          end

          def limits_for(job)
            LIMITS.map { |limit| limit.new(context, owners, job, jobs.size, state, config) }
          end

          def summary
            MSGS[:summary] % [owners.to_s, queueable.size, state.running_by_owners, jobs.size]
          end

          def report(*reports)
            self.reports.concat(reports).uniq!
          end

          def queueable
            @queueable ||= Job.by_owners(owners.all).queueable.to_a
          end

          def state
            @state ||= State.new(owners, config)
          end
      end
    end
  end
end
