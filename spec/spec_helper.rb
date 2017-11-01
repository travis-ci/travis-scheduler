ENV['ENV'] = ENV['RAILS_ENV'] = 'test'

require 'database_cleaner'
require 'mocha'
require 'support/env'
require 'support/features'
require 'webmock/rspec'
require 'support/factories'
require 'support/logger'
require 'support/stages'
require 'support/rollout'
require 'travis/scheduler'

include Mocha::API

Travis::Scheduler.setup

DatabaseCleaner.clean_with :truncation
DatabaseCleaner.strategy = :transaction

WebMock.disable_net_connect!

RSpec.configure do |c|
  c.mock_with :mocha
  c.include Support::Env
  c.include Support::Features
  c.include Support::Logger
  c.include Support::Rollout
  c.include FactoryGirl::Syntax::Methods
  # c.backtrace_clean_patterns = []

  # TODO for webmock request expectation
  c.raise_errors_for_deprecations!

  c.before do
    DatabaseCleaner.start
    Time.now.utc.tap { |now| Time.stubs(:now).returns(now) }
    Travis::Scheduler.instance_variable_set(:@context, nil)
    Travis::Scheduler.instance_variable_set(:@config, nil) # TODO remove once everything uses context
    Travis::Scheduler.redis.flushall
    Travis::Amqp::Publisher.any_instance.stubs(:publish)
  end

  c.after do
    DatabaseCleaner.clean
  end
end
