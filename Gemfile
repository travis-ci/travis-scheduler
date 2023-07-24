source 'https://rubygems.org'

ruby '3.2.2'

gem 'travis-config',  path: '~/tmp/travis-config'
gem 'travis-lock'
gem 'travis-metrics',    path: '~/tmp/travis-metrics'# git: 'https://github.com/travis-ci/travis-metrics'
gem 'travis-rollout',   git: 'https://github.com/travis-ci/travis-rollout'
gem 'travis-exceptions', path: '~/tmp/travis-exceptions'# git: 'https://github.com/travis-ci/travis-exceptions'
gem 'travis-logger',     path: '~/tmp/travis-logger'# git: 'https://github.com/travis-ci/travis-logger'
gem 'travis-settings', path: '~/tmp/travis-settings'#   git: 'https://github.com/travis-ci/travis-settings'
gem 'gh',           path: '~/tmp/gh'#      git: 'https://github.com/travis-ci/gh'
gem 'coder',              git: 'https://github.com/rkh/coder'

gem 'metriks',        path: '~/tmp/metriks'#         git: 'https://github.com/travis-ci/metriks'
gem 'metriks-librato_metrics', path: '~/tmp/metriks-librato_metrics' #git: 'https://github.com/travis-ci/metriks-librato_metrics'

gem 'marginalia', path: '~/tmp/marginalia'#git: 'https://github.com/travis-ci/marginalia'

gem 'cl'
gem 'sidekiq-pro', require: 'sidekiq-pro', source: 'https://gems.contribsys.com'
gem 'redis-namespace'
gem 'activerecord',       '~> 7'
gem 'bunny',              '~> 2.22'
gem 'pg'
gem 'concurrent-ruby'
gem 'sentry-raven'
gem 'rollout'
gem 'redlock'
gem 'multi_json',         '~> 1.15'
gem 'rack',               '>= 3.0'

gem 'libhoney'
gem 'faraday', '~> 2'

group :development, :test do
  gem 'pry'
end

group :test do
  gem 'rake'
  gem 'database_cleaner', '~> 2.0'
  gem 'factory_bot'
  gem 'mocha',            '~> 2.0'
  gem 'rspec'
  gem 'webmock'
end
