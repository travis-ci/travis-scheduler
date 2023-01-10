require 'travis/config'

module Travis
  module Scheduler
    class Config < Travis::Config
      class << self
        def amqp_username
          ENV['TRAVIS_AMQP_USERNAME'] || 'guest'
        end

        def amqp_password
          ENV['TRAVIS_AMQP_PASSWORD'] || 'guest'
        end

        def billing_auth_keys
          ENV['TRAVIS_BILLING_AUTH_KEYS'] || 'auth_keys'
        end

        def travis_site
          ENV['TRAVIS_SITE'] || 'org'
        end

        def job_board_url
          ENV['JOB_BOARD_URL'] || 'https://job-board.travis-ci.org'
        end

        def job_board_auth
          ENV['JOB_BOARD_AUTH'] || 'user:pass'
        end
      end

      define amqp:          { username: amqp_username, password: amqp_password, host: 'localhost', prefetch: 1 },
             database:      { adapter: 'postgresql', database: "travis_#{env}", encoding: 'unicode', min_messages: 'warning' },
             delegate:      { },
             encryption:    { key: SecureRandom.hex(64) },
             enterprise:    false,
             github:        { api_url: 'https://api.github.com', source_host: 'github.com' },
             billing:       { url: 'http://localhost:9292/', auth_key: billing_auth_keys },
             host:          'https://travis-ci.com',
             interval:      2,
             limit:         { public: 5, education: 1, default: 5, by_owner: {}, delegate: {} },
             lock:          { strategy: :redis, ttl: 150 },
             logger:        { time_format: false, process_id: false, thread_id: false },
             log_level:     :info,
             metrics:       { reporter: 'librato' },
             plans:         { },
             queue:         { default: 'builds.gce', redirect: {} },
             queues:        [ queue: 'name', os: 'os', dist: 'dist', group: 'group', sudo: false, osx_image: 'osx_image', language: 'language', owner: 'owner', slug: 'slug', services: ['service']],
             redis:         { url: 'redis://localhost:6379' },
             sentry:        { },
             sidekiq:       { namespace: 'sidekiq', pool_size: 3, log_level: :warn },
             ping:          { interval: 5 * 60 },
             site:          travis_site,
             ssl:           { },
             job_board:     { url: job_board_url, auth: job_board_auth },
             vcs_proxy_api: { url: 'http://vcs_proxy_api' }

      def metrics
        # TODO fix keychain?
        super.to_h.merge(librato: librato.to_h.merge(source: librato_source), graphite: graphite)
      end

      def com?
        site == 'com'
      end
    end
  end
end
