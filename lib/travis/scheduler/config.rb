require 'travis/config'

module Travis
  module Scheduler
    class Config < Travis::Config
      define amqp:       { username: 'guest', password: 'guest', host: 'localhost', prefetch: 1 },
             database:   { adapter: 'postgresql', database: "travis_#{env}", encoding: 'unicode', min_messages: 'warning' },
             delegate:   { },
             encryption: { key: SecureRandom.hex(64) },
             enterprise: false,
             github:     { api_url: 'https://api.github.com', source_host: 'github.com' },
             host:       'https://travis-ci.com',
             interval:   2,
             limit:      { public: 5, education: 1, default: 5, by_owner: {}, delegate: {} },
             lock:       { strategy: :redis, ttl: 150 },
             logger:     { time_format: false, process_id: false, thread_id: false },
             log_level:  :info,
             metrics:    { reporter: 'librato' },
             plans:      { },
             queue:      { default: 'builds.gce', redirect: {} },
             queues:     [ queue: 'name', os: 'os', dist: 'dist', group: 'group', sudo: false, osx_image: 'osx_image', language: 'language', owner: 'owner', slug: 'slug', services: ['service']],
             redis:      { url: 'redis://localhost:6379' },
             sentry:     { },
             sidekiq:    { namespace: 'sidekiq', pool_size: 3, log_level: :warn },
             ping:       { interval: 5 * 60 },
             site:       ENV['TRAVIS_SITE'] || 'org',
             ssl:        { },
             job_board:  { url: ENV['JOB_BOARD_URL'] || 'https://job-board.travis-ci.org', auth: ENV['JOB_BOARD_AUTH'] || 'user:pass' },
             rollout:    { force_precise_sudo_required_percentage: 0.05, force_linux_sudo_required_percentage: 0.05 }

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
