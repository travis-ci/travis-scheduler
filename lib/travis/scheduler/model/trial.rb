# frozen_string_literal: true

require 'travis/scheduler/helper/memoize'

module Travis
  module Scheduler
    module Model
      class Trial < Struct.new(:owners, :redis)
        include Helper::Memoize

        def active?
          count && count > -1
        end

        private

        def count
          counts.compact.map(&:to_i).max
        end
        memoize :count

        def counts
          owners.logins.map do |login|
            redis.get(key_for(login))
          end
        end

        def key_for(login)
          "trial:#{login}"
        end
      end
    end
  end
end
