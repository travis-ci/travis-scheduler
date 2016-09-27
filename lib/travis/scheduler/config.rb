require 'travis/config'

module Travis
  module Scheduler
    class Config < Travis::Config
      define  amqp:       { username: 'guest', password: 'guest', host: 'localhost', prefetch: 1 },
              database:   { adapter: 'postgresql', database: "travis_#{env}", encoding: 'unicode', min_messages: 'warning' },
              delegate:   { },
              encryption: { key: 'secret' * 10 },
              enterprise: false,
              github:     { api_url: 'https://api.github.com', source_host: 'github.com' },
              interval:   2,
              limit:      { strategy: 'default', default: 5, by_owner: {}, delegate: {} },
              lock:       { strategy: :redis, ttl: 150 },
              logger:     { time_format: false, process_id: true, thread_id: true },
              log_level:  :debug,
              metrics:    { reporter: 'librato' },
              plans:      { },
              queue:      { redirect: {} },
              redis:      { url: 'redis://localhost:6379' },
              sentry:     { },
              sidekiq:    { namespace: 'sidekiq', pool_size: 3 },
              ssl:        { }

      def queue
        # TODO fix keychain
        queue_redirections ? { redirect: queue_redirections } : super
      end
    end
  end
end
