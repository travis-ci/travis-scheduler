require 'rake'
require 'travis/migrations'

# Rails.application.config.paths.add("spec/support/db/create.sql", with: "#{Gem.loaded_specs['travis-migrations'].full_gem_path}/db/structure.sql")


task default: :spec

# FileUtils.cp("#{Gem.loaded_specs['travis-migrations'].full_gem_path}/db/structure.sql", 'spec/support/db/create.sql')

namespace :db do
  desc 'Create the test database'
  task :create do
    sh 'createdb travis' rescue nil
    sh 'psql -q < spec/support/db/create.sql'
  end
end
