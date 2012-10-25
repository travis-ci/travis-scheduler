require 'bundler/setup'
require 'travis'

$stdout.sync = true

Travis.config.update_periodically

Travis::Features.start
Travis::Exceptions::Reporter.start
Travis::Database.connect
Travis::Notification.setup

thread = run_periodically(Travis.config.queue.interval) { Job::Queueing::All.new.run }
thread.join

