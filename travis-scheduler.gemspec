Gem::Specification.new do |s|
  s.name        = 'travis-scheduler'
  s.version     = '0.0.1'
  s.summary     = 'Queuing all the things!'
  s.description = s.summary + '  With flair!'
  s.authors     = ['Travis CI GmbH']
  s.email       = ['contact+travis-enqueue@travis-ci.org']
  s.homepage    = 'https://github.com/travis-ci/travis-scheduler'
  s.license     = 'MIT'

  # travis-hub is not intended to be gem installable :smiley_cat:
  s.metadata['allowed_push_host'] = 'https://not-rubygems.example.com'

  s.files         = `git ls-files -z`.split("\x0")
  s.require_paths = %w(lib)
end
