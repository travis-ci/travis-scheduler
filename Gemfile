source 'https://rubygems.org'

ruby '2.4.2' if ENV['DYNO']

gem 'travis-config',      '~> 1.1.3'
gem 'travis-lock'
gem 'travis-metrics',     git: 'https://github.com/travis-ci/travis-metrics'
gem 'travis-rollout',     git: 'https://github.com/travis-ci/travis-rollout'
gem 'travis-exceptions',  git: 'https://github.com/travis-ci/travis-exceptions'
gem 'travis-logger',      git: 'https://github.com/travis-ci/travis-logger'
gem 'travis-settings',    git: 'https://github.com/travis-ci/travis-settings'
gem 'gh',                 git: 'https://github.com/travis-ci/gh'
gem 'coder',              git: 'https://github.com/rkh/coder'

gem 'metriks',                 git: 'https://github.com/travis-ci/metriks'
gem 'metriks-librato_metrics', git: 'https://github.com/travis-ci/metriks-librato_metrics'

gem 'marginalia', git: 'https://github.com/travis-ci/marginalia'

gem 'cl'
gem 'sidekiq-pro', require: 'sidekiq-pro', source: 'https://gems.contribsys.com'
gem 'jemalloc'
gem 'redis-namespace'
gem 'activerecord',       '~> 4.2.7'
gem 'bunny',              '~> 2.9.2'
gem 'pg'
gem 'concurrent-ruby'
gem 'sentry-raven'
gem 'rollout'
gem 'redlock'
gem 'multi_json',         '~> 1.11'
gem 'rack',               '>= 1.6.11'

gem 'libhoney'
gem 'faraday'

group :development, :test do
  gem 'pry'
end

group :test do
  gem 'rake'
  gem 'database_cleaner', '~> 1.7'
  gem 'factory_girl',     '~> 4.7.0'
  gem 'mocha',            '~> 0.10.0'
  gem 'rspec'
  gem 'webmock'
end
