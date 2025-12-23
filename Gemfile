# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.2.2'

gem 'coder',              git: 'https://github.com/rkh/coder'
gem 'gh',                 git: 'https://github.com/travis-ci/gh'
gem 'travis-config',      git: 'https://github.com/travis-ci/travis-config'
gem 'travis-exceptions',  git: 'https://github.com/travis-ci/travis-exceptions'
gem 'travis-lock',        git: 'https://github.com/travis-ci/travis-lock'
gem 'travis-logger',      git: 'https://github.com/travis-ci/travis-logger'
gem 'travis-metrics',     git: 'https://github.com/travis-ci/travis-metrics'
gem 'travis-rollout',     git: 'https://github.com/travis-ci/travis-rollout'
gem 'travis-settings',    git: 'https://github.com/travis-ci/travis-settings'

gem 'metriks',                 git: 'https://github.com/travis-ci/metriks'
gem 'metriks-librato_metrics', git: 'https://github.com/travis-ci/metriks-librato_metrics'

gem 'marginalia', git: 'https://github.com/travis-ci/marginalia'

gem 'activerecord', '~> 7'
gem 'bunny', '~> 2.22'
gem 'cl'
gem 'concurrent-ruby'
gem 'multi_json', '~> 1.15'
gem 'pg'
gem 'rack', '>= 3.2.3'
gem 'redis-namespace'
gem 'redlock'
gem 'rexml', '>= 3.3.9'
gem 'rollout'
gem 'sentry-ruby'
gem 'sidekiq', '>= 7.1.3'
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
