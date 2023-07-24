require 'travis/scheduler/helper/memoize'

module Travis
  module Scheduler
    module Model
      class Boost < Struct.new(:owners, :redis)
        include Helper::Memoize

        BOOST = 'scheduler.owner.limit.%s'

        def exists?
          boosts.any?
        end
        memoize :exists?

        def max
          boosts.map(&:to_i).inject(&:+).to_i
        end
        memoize :max

        private

        def boosts
          owners.logins.map { |login| boost_for(login) }.compact
        end
        memoize :boosts

        def boost_for(login)
          redis.get(key_for(login))
        end

        def key_for(login)
          BOOST % login
        end
      end
    end
  end
end
