require 'travis/scheduler/helper/context'
require 'travis/scheduler/helper/locking'
require 'travis/scheduler/helper/logging'
require 'travis/scheduler/helper/runner'
require 'travis/scheduler/helper/with'
require 'travis/support/registry'

module Travis
  module Scheduler
    module Service
      def self.[](key)
        Travis::Registry[:service][key]
      end

      include Context, Locking, Logging, Runner, With
    end
  end
end

require 'travis/scheduler/service/event'
require 'travis/scheduler/service/enqueue_job'
require 'travis/scheduler/service/enqueue_owners'
require 'travis/scheduler/service/notify'
