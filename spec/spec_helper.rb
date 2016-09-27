ENV['ENV'] = ENV['RAILS_ENV'] = 'test'

require 'travis/scheduler'
require 'database_cleaner'
require 'mocha'
require 'support/factories'
require 'support/logger'

include Mocha::API

DatabaseCleaner.clean_with :truncation
DatabaseCleaner.strategy = :transaction

RSpec.configure do |c|
  c.mock_with :mocha
  c.include Support::Logger
  # c.backtrace_clean_patterns = []

  c.before do
    DatabaseCleaner.start
    Time.now.utc.tap { |now| Time.stubs(:now).returns(now) }
    Travis::Scheduler.instance_variable_set(:@config, nil)
    Travis::Scheduler.redis.flushall
  end

  c.after do
    DatabaseCleaner.clean
  end
end
