require 'travis/scheduler/helper/logging'

module Travis
  module Scheduler
    class Limit
      class ByRepo < Struct.new(:owners, :job, :queued, :state, :config)
        include Logging

        def enqueue?
          unlimited? || by_settings
        end

        def reports
          @reports ||= []
        end

        private

          def unlimited?
            max == 0
          end

          def by_settings
            result = current < max
            report :repo_settings, max unless result
            result
          end

          def current
            state.running_by_repo(repo.id) + queued
          end

          def max
            repo.settings.maximum_number_of_builds.to_i
          end

          def repo
            job.repository
          end

          def report(key, value)
            reports << MSGS[:max] % [repo.slug, key.to_s.sub('by_', ''), value]
            value
          end
      end
    end
  end
end
