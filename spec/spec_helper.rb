ENV['RAILS_ENV'] ||= 'test'

require 'simplecov' if ENV['RAILS_ENV'] == 'test' && ENV['COVERAGE']
require 'travis/scheduler'
require 'travis/support'
require 'stringio'
require 'mocha'
require 'factory_girl'
require 'travis/migrations'

Travis::Scheduler::Schedule.new.setup
Travis::Scheduler.config.encryption.key = 'secret' * 10
Travis.logger = Logger.new(StringIO.new)

require 'support/active_record'
require 'support/factories'
require 'support/stubs'

include Mocha::API

DatabaseCleaner.clean_with :truncation
DatabaseCleaner.strategy = :transaction

RSpec.configure do |c|
  c.mock_with :mocha
  # c.backtrace_clean_patterns = []

  c.before(:each) do
    DatabaseCleaner.start
    Time.now.utc.tap { |now| Time.stubs(:now).returns(now) }
  end

  c.after :each do
    DatabaseCleaner.clean
  end
end
