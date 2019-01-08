require 'travis/scheduler/helper/memoize'
require 'travis/scheduler/jobs/limit/base'
require 'travis/scheduler/jobs/limit/queue'
require 'travis/scheduler/jobs/limit/repo'
require 'travis/scheduler/jobs/limit/stages'

module Travis
  module Scheduler
    module Jobs
      class Limits < Struct.new(:context, :owners, :state)
        include Helper::Memoize

        # These are ordered by how specific the limit is, from most specific to least.
        # In other orders, we may apply a stricter limit than is intended.
        NAMES = %w(stages repo queue)

        def accept(job)
          yield job if accept?(job)
        end

        def reports
          all.map(&:reports).flatten
        end
        memoize :reports

        private

          def accept?(job)
            all.all? { |limit| limit.accept?(job) }
          end

          def all
            @all ||= NAMES.map { |name| limit(name) }
          end

          def limit(name)
            Limit.const_get(name.camelize).new(context, owners, state)
          end
      end
    end
  end
end
