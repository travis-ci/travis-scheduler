require 'travis/honeycomb'

module Travis
  module Scheduler
    module Helper
      module Honeycomb
        def honeycomb(data)
          data.each do |key, value|
            Travis::Honeycomb.context.add(key.to_s, value)
          end
        end
      end
    end
  end
end
