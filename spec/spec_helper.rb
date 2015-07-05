ENV['RAILS_ENV'] ||= 'test'

require 'simplecov' if ENV['RAILS_ENV'] == 'test' && ENV['COVERAGE']

require 'travis/scheduler'
require 'travis/support'
require 'support/active_record'
require 'support/stubs'
require 'stringio'
require 'mocha'
# require 'travis/testing/matchers'

Travis.logger = Logger.new(StringIO.new)
# Travis.services = Travis::Services

include Mocha::API

DatabaseCleaner.clean_with :truncation
DatabaseCleaner.strategy = :transaction

RSpec.configure do |c|
  c.mock_with :mocha
  c.backtrace_clean_patterns = []

  c.before(:each) do
    DatabaseCleaner.start
    Time.now.utc.tap { |now| Time.stubs(:now).returns(now) }
  end

  c.after :each do
    DatabaseCleaner.clean
  end
end
