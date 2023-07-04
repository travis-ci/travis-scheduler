ENV['ENV'] = ENV['RAILS_ENV'] = 'test'
ENV.delete('DATABASE_URL')

NOWISH = Time.now

require 'travis/scheduler'
require 'database_cleaner'
require 'mocha'
require 'support/env'
require 'support/features'
require 'support/github_apps'
require 'webmock/rspec'
require 'support/factories'
require 'support/logger'
require 'support/record'
require 'support/stages'
require 'support/rollout'
require 'support/queues'

Travis::Scheduler.setup

DatabaseCleaner.clean_with :truncation
DatabaseCleaner.strategy = :transaction
DatabaseCleaner.allow_remote_database_url = true

WebMock.disable_net_connect!

RSpec.configure do |c|
  c.mock_with :mocha
  c.include Support::Env
  c.include Support::Features
  c.include Support::Logger
  c.include Support::Rollout
  c.include FactoryBot::Syntax::Methods
  # c.backtrace_clean_patterns = []

  # TODO for webmock request expectation
  c.raise_errors_for_deprecations!


  if ENV['SHOW_QUERIES']
    sql_count = {}
    sql_count.default = 0
    c.before(:suite) do
      ActiveSupport::Notifications.subscribe 'sql.active_record' do |*args|
        event = ActiveSupport::Notifications::Event.new *args
        sql_count[event.payload[:name]] +=1
     end
    end
  end

  c.before do
    DatabaseCleaner.start
    Time.now.utc.tap { |now| Time.stubs(:now).returns(now) }
    Travis::Scheduler.instance_variable_set(:@context, nil)
    Travis::Scheduler.instance_variable_set(:@config, nil) # TODO remove once everything uses context
    Travis::Scheduler.redis.flushall
    Travis::Amqp::Publisher.any_instance.stubs(:publish)
    ENV['IBM_REPO_SWITCHES_DATE'] = '2021-10-01'
  end

  c.after do
    DatabaseCleaner.clean
    ENV['IBM_REPO_SWITCHES_DATE'] = nil
  end

  if ENV['SHOW_QUERIES']
    c.after(:suite) do
      puts "\nNumber of SQL queries performed:"
      puts JSON.pretty_generate(sql_count)
    end
  end
end
