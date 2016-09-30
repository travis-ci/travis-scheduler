module Travis
  module Scheduler
    module Limit
      class State
        BOOST = 'scheduler.owner.limit.%s'

        attr_reader :owners, :config

        def initialize(owners, config = {})
          @owners = owners
          @config = config
          @count  = { repo: {} }
          @boosts = {}
        end

        def running_by_owners
          @count[:owners] ||= Job.by_owners(owners.all).running.count
        end

        def running_by_repo(id)
          @count[:repo][id] ||= Job.by_repo(id).running.count
        end

        def boost_for(login)
          @boosts[login] ||= Scheduler.redis.get(BOOST % login).to_i
        end
      end
    end
  end
end
