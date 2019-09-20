require 'travis/support/filter_migrated_jobs'

module Travis
  module Scheduler
    module Limit
      class State
        BOOST = 'scheduler.owner.limit.%s'
        include FilterMigratedJobs

        attr_reader :owners, :config

        def initialize(owners, config = {})
          @owners = owners
          @config = config
          @count  = { repo: {}, queue: {} }
          @boosts = {}
        end

        def running_by_owners
          @count[:owners] ||= filter_running_jobs(running_jobs_by_owners).count
        end

        def running_by_owners_public
          @count[:public] ||= filter_running_jobs(running_jobs_by_owners.where(private: false)).count
        end

        def running_by_repo(id)
          @count[:repo][id] ||= filter_running_jobs(Job.by_repo(id).running).count
        end

        def running_by_queue(queue)
          @count[:queue][queue] ||= filter_running_jobs(Job.by_owners(owners.all).by_queue(queue).running).count
        end

        def boost_for(login)
          @boosts[login] ||= Scheduler.redis.get(BOOST % login).to_i
        end

        private

          def running_jobs_by_owners
            @running_jobs_by_owners ||= Job.by_owners(owners.all).running
          end

          def filter_running_jobs(jobs)
            filter_migrated_jobs(jobs)
          end
      end
    end
  end
end
