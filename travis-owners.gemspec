Gem::Specification.new do |s|
  s.name        = 'travis-owners'
  s.version     = '0.0.1'
  s.summary     = 'Owner groups'
  s.description = s.summary + ' with style.'
  s.authors     = ['Travis CI GmbH']
  s.email       = ['contact+travis-owners@travis-ci.org']
  s.homepage    = 'https://github.com/travis-ci/travis-scheduler'
  s.license     = 'MIT'

  # travis-owners is not intended to be an installable gem :smiley_cat:
  s.metadata['allowed_push_host'] = 'https://not-rubygems.example.com'

  s.files         = `git ls-files -z`.split("\x0").grep(%r(lib/travis/owners(.rb|/)))
  s.require_paths = %w(lib)
end
