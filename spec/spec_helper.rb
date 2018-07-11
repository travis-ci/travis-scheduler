ENV['ENV'] = ENV['RAILS_ENV'] = 'test'
ENV.delete('DATABASE_URL')

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
  end

  c.after do
    DatabaseCleaner.clean
  end

  if ENV['SHOW_QUERIES']
    c.after(:suite) do
      puts "\nNumber of SQL queries performed:"
      puts JSON.pretty_generate(sql_count)
    end
  end

end

module SpecHelper
  NOWISH = Time.now

  def qc(*args)
    QueueCase.new(*args)
  end

  class QueueCase
    def initialize(cutoff: NOWISH.to_s, host: 'travis-ci.org', config: {},
                   desc: 'uh???', queue: 'notset', education: false,
                   created_at: NOWISH + 7.days, force_precise_sudo_required: false,
                   force_linux_sudo_required: false)
      @cutoff = cutoff
      @host = host
      @config = config
      @desc = desc
      @queue = queue
      @education = education
      @created_at = created_at
      @force_precise_sudo_required = force_precise_sudo_required
      @force_linux_sudo_required = force_linux_sudo_required
    end

    attr_reader :created_at, :config, :cutoff, :desc, :host, :queue

    def education?
      @education
    end

    def force_precise_sudo_required?
      @force_precise_sudo_required
    end

    def force_linux_sudo_required?
      @force_linux_sudo_required
    end

    def to_s
      a = %w[when on]
      a << (host =~ /\.org/ ? 'org' : 'com')
      a << 'educational' if education?
      a << "sudo=#{config[:sudo]}" if config.key?(:sudo)
      a << "dist=#{config[:dist]}" if config.key?(:dist)
      if force_precise_sudo_required?
        a << "forced sudo required because of dist: precise"
      end
      a << "forced sudo required on linux" if force_linux_sudo_required?
      a << 'and created'
      a << (created_at < Time.parse(cutoff) ? "before" : "after")
      a << 'cutoff'
      a.join(' ')
    end
  end
end
