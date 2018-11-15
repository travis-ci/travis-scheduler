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

        NAMES = %w(repo queue stages)

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
