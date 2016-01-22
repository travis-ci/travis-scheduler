source 'https://rubygems.org'

ruby '2.1.5' if ENV['DYNO']

gem 'travis-support',     github: 'travis-ci/travis-support', ref: 'sf-instrumentation'
gem 'travis-settings',    github: 'travis-ci/travis-settings'
gem 'travis-lock',        github: 'travis-ci/travis-lock'
gem 'travis-config',      '~> 1.0.0rc1'

gem 'rake'
gem 'activerecord'
gem 'dalli'

gem 'sentry-raven',       github: 'getsentry/raven-ruby'
gem 'metriks-librato_metrics'
gem 'rails_12factor'
gem 'virtus'

# can't be removed yet, even though we're on jruby 1.6.7 everywhere
# this is due to Invalid gemspec errors
gem 'rollout',            github: 'jamesgolick/rollout', ref: 'v1.1.0'
gem 'sidekiq'
gem 'bunny'
gem 'pg'
gem 'redlock'

gem 'coder',              github: 'rkh/coder'

group :test do
  gem 'database_cleaner', '~> 0.8.0'
  gem 'guard'
  gem 'guard-rspec'
  gem 'mocha',            '~> 0.10.0'
  gem 'rspec'
  gem 'rubocop',          require: false
  gem 'ruby-progressbar', '1.7.1' # this should not be needed, but rubygems is giving me an old version for some reason, well, a newer version which was yanked
  gem 'simplecov',        require: false
  gem 'webmock',          '~> 1.8.0'
  gem 'factory_girl'
end
