require 'travis/config'

module Travis
  module Scheduler
    class Config < Travis::Config
      define  amqp:          { username: 'guest', password: 'guest', host: 'localhost', prefetch: 1 },
              database:      { adapter: 'postgresql', database: "travis_development", encoding: 'unicode', min_messages: 'warning' },
              encryption:    { },
              github:        { },
              interval:      2,
              limit:         { strategy: 'default', default: 5, by_owner: {}, delegate: {} },
              logger:        { time_format: false, process_id: true, thread_id: true },
              metrics:       { reporter: 'librato' },
              notifications: [],
              plans:         { },
              pusher:        { app_id: 'app-id', key: 'key', secret: 'secret', secure: false },
              redis:         { url: 'redis://localhost:6379' },
              sentry:        { },
              sidekiq:       { namespace: 'sidekiq', pool_size: 3 },
              ssl:           { }
    end
  end
end
