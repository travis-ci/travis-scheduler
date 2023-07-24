#!/usr/bin/env ruby
# frozen_string_literal: true

# This script takes a job id and spits out the job payload for that id
# Usage:
# `heroku run -a travis-scheduler-<stage> script/generate-job-payload <job ID>`

$: << 'lib'
require 'bundler/setup'
require 'travis/scheduler'

# Silence Raven so output can be piped directly elsewhere.
Travis::Scheduler.logger = Logger.new(IO::NULL)

require 'raven/logger'
module Raven
  class Logger
    def add(*); end
  end
end

Travis::Scheduler.setup

id = Integer(ARGV[0])
job = Job.find(id)
config = Travis::Scheduler::Config.load

payload = Travis::Scheduler::Serialize::Worker.new(job, config).data
payload.delete(:cache_settings)

puts JSON.generate(payload)
