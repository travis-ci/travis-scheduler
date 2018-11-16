require 'factory_girl'

Job.class_eval do
  def public=(value)
    self.private = !value
  end
end

FactoryGirl.define do
  REPO_KEY = OpenSSL::PKey::RSA.generate(4096)

  factory :user do
    login 'svenfuchs'
    github_oauth_token 'token'
  end

  factory :org, :class => 'Organization' do
    login 'travis-ci'
  end

  factory :subscription do
    valid_to Time.now + 24 * 3600
  end

  factory :trial

  factory :repository, aliases: [:repo] do
    name       'gem-release'
    github_id  549743
    owner      { User.first || FactoryGirl.create(:user) }
    owner_name { owner.login }
    key        { SslKey.create(public_key: REPO_KEY.public_key, private_key: REPO_KEY.to_pem) }
    users      { [ owner ] }
    settings   {}

    # TODO why is the worker payload interested in these at all?
    last_build_id 1
    last_build_started_at '2016-01-01T10:00:00Z'
    last_build_finished_at '2016-01-01T11:00:00Z'
    last_build_number 2
    last_build_duration 60
    last_build_state :passed
    description 'description'
  end

  factory :installation

  factory :job do
    owner      { User.first || FactoryGirl.create(:user) }
    repository { Repository.first || FactoryGirl.create(:repository) }
    source     { FactoryGirl.create(:build) }
    commit     { FactoryGirl.create(:commit) }
    config     {}
    number     '2.1'
    queue      'builds.gce'
    state      :created
    queueable  true
  end

  factory :build do
    request { Request.first || FactoryGirl.create(:request) }
    number 2
    event_type :push
  end

  factory :stage

  factory :request do
    event_type 'push'
  end

  factory :pull_request do
  end

  factory :commit do
    request         { Request.first || FactoryGirl.create(:request) }
    commit          '62aaef'
    branch          'master'
    message         'message'
    compare_url     'https://github.com/svenfuchs/minimal/compare/0cd9ff...62aaef'
    committed_at    '2016-01-01T12:00:00Z'
    committer_email 'me@svenfuchs.com'
    committer_name  'Sven Fuchs'
    author_name     'Sven Fuchs'
    author_email    'me@svenfuchs.com'
  end
end

