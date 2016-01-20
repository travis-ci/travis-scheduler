require 'rake'
require 'fileutils'
require 'travis/migrations'

task default: :spec


namespace :db do
  desc 'Create the test database'
  task :create do
    open("#{Gem.loaded_specs['travis-migrations'].full_gem_path}/db/structure.sql", 'a') { |f|
      f.puts "\connect travis_test"
    }
    FileUtils.cp("#{Gem.loaded_specs['travis-migrations'].full_gem_path}/db/structure.sql", 'spec/support/db/structure.sql')
    sh 'createdb travis_test' rescue nil
    sh 'psql -q < spec/support/db/create.sql'
  end
end
