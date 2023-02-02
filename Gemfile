source 'https://rubygems.org'

ruby '2.7.5'

gem 'travis-config',      '~> 1.1.3'
gem 'travis-lock',     git: 'https://github.com/travis-ci/travis-lock/', branch: '6.1'
gem 'travis-metrics',     git: 'https://github.com/travis-ci/travis-metrics'
gem 'travis-rollout',     git: 'https://github.com/travis-ci/travis-rollout'
gem 'travis-exceptions',  git: 'https://github.com/travis-ci/travis-exceptions', branch: '6.1'
gem 'travis-logger',      git: 'https://github.com/travis-ci/travis-logger'
gem 'travis-settings',    git: 'https://github.com/travis-ci/travis-settings', branch: '6.1'
gem 'gh',                 git: 'https://github.com/travis-ci/gh', branch: '6.1'
gem 'coder',              git: 'https://github.com/rkh/coder'

gem 'metriks',                 git: 'https://github.com/travis-ci/metriks'
gem 'metriks-librato_metrics', git: 'https://github.com/travis-ci/metriks-librato_metrics'

gem 'marginalia', git: 'https://github.com/travis-ci/marginalia', branch: '6.1'

gem 'cl'
gem 'sidekiq-pro', require: 'sidekiq-pro', source: 'https://gems.contribsys.com'
gem 'sidekiq', '~> 6.4'
gem 'redis-namespace'
gem 'activerecord',       '~> 6.1.7.2'
gem 'bunny',              '~> 2.9.2'
gem 'pg'
gem 'concurrent-ruby'
gem 'sentry-raven'
gem 'rollout'
gem 'redlock'
gem 'multi_json',         '~> 1.11'
gem 'rack',               '>= 2.1.4'

gem 'libhoney'
gem 'faraday'

group :development, :test do
  gem 'pry'
end

group :test do
  gem 'rake'
  gem 'database_cleaner'
  gem 'factory_girl'
  gem 'mocha',            '~> 0.10.0'
  gem 'rspec'
  gem 'webmock'
end
