require 'rake'
require 'fileutils'
require 'travis/migrations'

task default: :spec

FileUtils.cp("#{Gem.loaded_specs['travis-migrations'].full_gem_path}/db/structure.sql", 'spec/support/db/structure.sql')

namespace :db do
  desc 'Create the test database'
  task :create do
    sh 'createdb travis_test' rescue nil
    sh 'psql -q < spec/support/db/structure.sql'
  end
end
