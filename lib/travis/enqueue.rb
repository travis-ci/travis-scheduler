require 'travis'

$stdout.sync = true

Travis.config.update_periodically
Travis.config.queue.interval = 15
Travis::Amqp.config = Travis.config.amqp

Travis::Features.start
Travis::Exceptions::Reporter.start
Travis::Database.connect
Travis::Notification.setup

thread = run_periodically(Travis.config.queue.interval) do
  print "about to enqueue jobs ... "
  jobs = Job::Queueing::All.new.run
  puts "done (enqueued #{Array(jobs).compact.size} jobs)"
end
thread.join

