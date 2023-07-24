# frozen_string_literal: true

require 'travis/scheduler'

Travis::Scheduler.setup
Travis::Scheduler.ping
# Travis::Scheduler::Ping.new(Travis::Scheduler.context).start
