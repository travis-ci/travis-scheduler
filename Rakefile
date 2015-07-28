require 'rake'

task default: :spec

namespace :db do
  desc 'Create the test database'
  task :create do
    dbname = 'travis'
    dbname = 'travis_test' if ENV['RAILS_ENV'] == 'test'
    sh "createdb #{dbname}"
    sh 'psql -q < spec/support/db/create.sql'
  end
end

