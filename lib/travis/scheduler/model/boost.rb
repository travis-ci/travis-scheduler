require 'travis/scheduler/helper/memoize'

module Travis
  module Scheduler
    module Model
      class Boost < Struct.new(:owners, :redis)
        include Helper::Memoize

        BOOST = 'scheduler.owner.limit.%s'

        def max
          owners.logins.map { |login| boost_for(login) }.inject(&:+)
        end
        memoize :max

        private

          def boost_for(login)
            redis.get(key_for(login)).to_i
          end

          def key_for(login)
            BOOST % login
          end
      end
    end
  end
end
