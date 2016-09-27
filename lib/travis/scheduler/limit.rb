module Travis
  module Scheduler
    class Limit < Struct.new(:owners, :config)
      require 'travis/scheduler/limit/by_owner'
      require 'travis/scheduler/limit/by_repo'
      require 'travis/scheduler/limit/state'

      LIMITS = [ByOwner, ByRepo]

      MSGS = {
        max:      'max jobs for %s by %s: %s',
        max_plan: 'max jobs for %s by %s: %s (%s)',
        summary:  '%s: total: %s, running: %s, queueable: %s'
      }

      def run
        check_all
        report summary
      end

      def reports
        @reports ||= []
      end

      def queueable
        @queueable ||= []
      end

      private

        def check_all
          jobs.each do |job|
            case check(job)
            when :limited
              break
            when true
              queueable << job
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
          LIMITS.map { |limit| limit.new(owners, job, queueable.size, state, config) }
        end

        def summary
          MSGS[:summary] % [owners.logins.join(', '), jobs.size, state.running_by_owners, queueable.size]
        end

        def report(*reports)
          self.reports.concat(reports).uniq!
        end

        def jobs
          @jobs ||= Job.by_owners(owners.all).queueable.to_a
        end

        def state
          @state ||= State.new(owners, config)
        end
    end
  end
end

