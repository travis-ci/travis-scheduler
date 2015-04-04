require 'travis/config'

module Travis
  module Scheduler
    class Config < Travis::Config
      define  database: { adapter: 'postgresql', database: "travis_development", encoding: 'unicode', min_messages: 'warning' },
              pusher:   { app_id: 'app-id', key: 'key', secret: 'secret', secure: false },
              sidekiq:  { namespace: 'sidekiq', pool_size: 3 },
              redis:    { url: 'redis://localhost:6379' },
              metrics:  { reporter: 'librato' },
              logger:   { time_format: false, process_id: true, thread_id: true },
              ssl:      { },
              sentry:   { },
              sync:     { } 

      default _access: [:key]

      def self.env
        ENV['ENV'] || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
      end

      def env
        self.class.env
      end
    end
  end
end
