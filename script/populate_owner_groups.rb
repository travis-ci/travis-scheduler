require 'yaml'

USAGE = 'ruby script/populate_owner_groups [org|com] [staging|production]'

APPS = {
  staging: {
    org: 'travis-scheduler-staging',
    com: 'travis-pro-scheduler-staging'
  },
  production: {
    org: 'travis-scheduler-production',
    com: 'travis-pro-scheduler-prod'
  }
}

def group(hash)
  hash = hash.each_with_object({}) do |(key, value), hash|
    hash[value] ||= [value]
    hash[value] << key
  end
  hash.values
end

abort(USAGE) unless ARGV.size >= 2

target = ARGV.shift
env    = ARGV.shift
app    = APPS[env.to_sym][target.to_sym]
path   = "tmp/delegate.#{target}.yml"
config = YAML.load_file(path)
owners = config['delegate']
groups = group(owners)

groups.each do |group|
  cmd = "bundle exec bin/run owners group #{group.join(' ')}"
  # cmd = "heroku run '#{cmd}' -a #{app}"
  puts cmd
  system cmd unless ARGV[0] == '--dry-run'
end
