require 'travis/config'

module Travis
  module Scheduler
    class Config < Travis::Config
      define  amqp:           { username: 'guest', password: 'guest', host: 'localhost', prefetch: 1 },
              database:       { adapter: 'postgresql', database: "travis_development", encoding: 'unicode', min_messages: 'warning' },
              github:         { },
              interval:       3
              limit:          { strategy: 'default', default: 5, by_owner: {} },
              logger:         { time_format: false, process_id: true, thread_id: true },
              metrics:        { reporter: 'librato' },
              notifications:  [],
              pusher:         { app_id: 'app-id', key: 'key', secret: 'secret', secure: false },
              redis:          { url: 'redis://localhost:6379' },
              sentry:         { },
              sidekiq:        { namespace: 'sidekiq', pool_size: 3 },
              ssl:            { }

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
