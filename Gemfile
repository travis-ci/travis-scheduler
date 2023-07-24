source 'https://rubygems.org'

ruby '3.2.2'

gem 'coder',              git: 'https://github.com/rkh/coder'
gem 'gh',                 git: 'https://github.com/travis-ci/gh', branch: 'prd-ruby-upgrade-dev'
gem 'travis-config',      git: 'https://github.com/travis-ci/travis-config', branch: 'prd-ruby-upgrade-dev'
gem 'travis-exceptions',  git: 'https://github.com/travis-ci/travis-exceptions', branch: 'prd-ruby-upgrade-dev'
gem 'travis-lock',        git: 'https://github.com/travis-ci/travis-lock', branch: 'prd-ruby-upgrade-dev'
gem 'travis-logger',      git: 'https://github.com/travis-ci/travis-logger', branch: 'prd-ruby-upgrade-dev'
gem 'travis-metrics',     git: 'https://github.com/travis-ci/travis-metrics', branch: 'prd-ruby-upgrade-dev'
gem 'travis-rollout',     git: 'https://github.com/travis-ci/travis-rollout'
gem 'travis-settings',    git: 'https://github.com/travis-ci/travis-settings', branch: 'prd-ruby-upgrade-dev'

gem 'metriks',                 git: 'https://github.com/travis-ci/metriks', branch: 'prd-ruby-upgrade-dev'
gem 'metriks-librato_metrics', git: 'https://github.com/travis-ci/metriks-librato_metrics',
                               branch: 'prd-ruby-upgrade-dev'

gem 'marginalia', git: 'https://github.com/travis-ci/marginalia', branch: 'prd-ruby-upgrade-dev'

gem 'activerecord', '~> 7'
gem 'bunny', '~> 2.22'
gem 'cl'
gem 'concurrent-ruby'
gem 'multi_json', '~> 1.15'
gem 'pg'
gem 'rack', '>= 3.0'
gem 'redis-namespace'
gem 'redlock'
gem 'rollout'
gem 'sentry-raven'
gem 'sidekiq-pro', require: 'sidekiq-pro', source: 'https://gems.contribsys.com'

gem 'faraday', '~> 2'
gem 'libhoney'

group :development, :test do
  gem 'pry'
end

group :test do
  gem 'database_cleaner', '~> 2.0'
  gem 'factory_bot'
  gem 'mocha', '~> 2.0'
  gem 'rake'
  gem 'rspec'
  gem 'webmock'
end

group :development, :test do
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rspec', require: false
  gem 'simplecov', require: false
  gem 'simplecov-console', require: false
end
