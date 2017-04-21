require 'travis/scheduler/helper/context'
require 'travis/scheduler/helper/logging'

module Travis
  module Scheduler
    module Limit
      class ByRepo < Struct.new(:context, :owners, :job, :selected, :state, :config)
        include Helper::Context

        def enqueue?
          # return false unless by_config
          # return false if max_by_setting && !by_setting
          # p [max_by_setting, by_setting]
          # unlimited? || by_setting
          return false if limited_by_config?
          return false if limited_by_setting?
          true
        end

        def reports
          @reports ||= []
        end

        private

          def limited_by_config?
            result = max_by_config > 0 && current >= max_by_config
            report :repo_config, max_by_config if result
            result
          end

          def limited_by_setting?
            result = max_by_setting > 0 && current >= max_by_setting
            report :repo_settings, max_by_setting if result
            result
          end

          def current
            state.running_by_repo(repo.id) + selected.select { |j| j.repository_id == repo.id }.size
          end

          def max_by_setting
            repo.settings.maximum_number_of_builds.to_i
          end

          def max_by_config
            config[:limit][:by_repo][repo.slug].to_i
          end

          def repo
            job.repository
          end

          def report(key, value)
            reports << MSGS[:max] % ["repo #{repo.slug}", key.to_s.sub('by_', ''), value]
            value
          end
      end
    end
  end
end
