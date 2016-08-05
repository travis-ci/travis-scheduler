require 'travis/scheduler/services/notify'
require 'travis/support/registry'

module Travis
  module Scheduler
    module Services
      def self.[](key)
        Travis::Registry[:service][key]
      end
    end
  end
end
