source :rubygems

# ruby '1.9.3', engine: 'jruby', engine_version: '1.7.0'
ruby '1.9.3'

gem 'travis-core',    github: 'travis-ci/travis-core'
gem 'travis-support', github: 'travis-ci/travis-support'

gem 'hubble',         github: 'roidrage/hubble'
gem 'rollout',        github: 'jamesgolick/rollout', :ref => 'v1.1.0'

platform :jruby do
  gem 'activerecord-jdbcpostgresql-adapter', '~> 1.2.2'
  gem 'hot_bunnies'
end

platform :mri do
  gem 'pg'
  gem 'bunny'
end

group :test do
  gem 'rspec',        '~> 2.7.0'
  gem 'mocha',        '~> 0.10.0'
  gem 'guard'
  gem 'guard-rspec'
end
