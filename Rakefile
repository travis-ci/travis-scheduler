require 'rake'
require 'travis/migrations'

task default: :spec

namespace :db do
  desc 'Create the test database'
  task :create do
    sh 'createdb travis_test' rescue nil
    sh "cp #{Gem.loaded_specs['travis-migrations'].full_gem_path}/db/structure.sql spec/support/db/create.sql"
    sh 'psql -q travis_test < spec/support/db/create.sql'
  end
end
