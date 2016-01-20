require 'rake'
require 'fileutils'
require 'travis/migrations'

task default: :spec


namespace :db do
  desc 'Create the test database'
  task :create do
    FileUtils.cp("#{Gem.loaded_specs['travis-migrations'].full_gem_path}/db/structure.sql", 'spec/support/db/create.sql')
    sh 'createdb travis_test' rescue nil
    sh 'psql -q < spec/support/db/create.sql'
  end
end
