describe Travis::Scheduler::Limit::Jobs do
  let(:org)     { FactoryGirl.create(:org, login: 'travis-ci') }
  let(:repo)    { FactoryGirl.create(:repo) }
  let(:build)   { FactoryGirl.create(:build) }
  let(:owner)   { FactoryGirl.create(:user) }
  let(:owners)  { Travis::Scheduler::Model::Owners.new(data, config) }
  let(:context) { Travis::Scheduler.context }
  let(:redis)   { context.redis }
  let(:config)  { context.config }
  let(:data)    { { owner_type: 'User', owner_id: owner.id } }
  let(:limit)   { described_class.new(context, owners) }
  let(:report)  { limit.reports }

  before  { config.limit.trial = nil }
  before  { config.limit.default = 1 }
  before  { config.plans = { one: 1, seven: 7, ten: 10 } }
  subject { limit.run; limit.selected }

  def create_jobs(count, owner, state, repo = nil, queue = nil, stage_number = nil, stage = nil)
    1.upto(count) { FactoryGirl.create(:job, repository: repo || self.repo, owner: owner, source: build, state: state, queue: queue, stage_number: stage_number, stage: stage) }
  end

  describe 'with a boost limit 2' do
    before { create_jobs(3, owner, :created, true) }
    before { redis.set("scheduler.owner.limit.#{owner.login}", 2) }
    before { subject }

    it { expect(subject.size).to eq 2 }
    it { expect(report).to include('max jobs for user svenfuchs by boost: 2') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 2') }
  end

  describe 'with a subscription limit 1' do
    before { create_jobs(3, owner, :created, true) }
    before { FactoryGirl.create(:subscription, valid_to: Time.now.utc, owner_type: owner.class.name, owner_id: owner.id, selected_plan: :one) }
    before { subject }

    it { expect(subject.size).to eq 1 }
    it { expect(report).to include('max jobs for user svenfuchs by plan: 1 (svenfuchs)') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 1') }
  end

  describe 'with a custom config limit unlimited' do
    before { create_jobs(3, owner, :created, true) }
    before { config.limit.by_owner[owner.login] = -1 }
    before { subject }

    it { expect(subject.size).to eq 3 }
    it { expect(report).to include('max jobs for user svenfuchs by unlimited: true') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 3') }
  end

  describe 'with a custom config limit 1' do
    before { create_jobs(3, owner, :created, true) }
    before { config.limit.by_owner[owner.login] = 1 }
    before { subject }

    it { expect(subject.size).to eq 1 }
    it { expect(report).to include('max jobs for user svenfuchs by config: 1') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 1') }
  end

  describe 'with a trial' do
    before { create_jobs(3, owner, :created, true) }
    before { config.limit.trial = 2 }
    before { context.redis.set("trial:#{owner.login}", 5) }
    before { subject }

    it { expect(subject.size).to eq 2 }
    it { expect(report).to include('max jobs for user svenfuchs by trial: 2') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 2') }
  end

  describe 'with a default limit 1' do
    before { create_jobs(3, owner, :created, true) }
    before { config.limit.default = 1 }
    before { subject }

    it { expect(subject.size).to eq 1 }
    it { expect(report).to include('max jobs for user svenfuchs by default: 1') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 1') }
  end

  describe 'with a default limit 5 and a repo settings limit 2' do
    before { config.limit.default = 5 }
    before { create_jobs(3, owner, :created, true) }
    before { repo.settings.update_attributes!(maximum_number_of_builds: 2) }
    before { subject }

    it { expect(subject.size).to eq 2 }
    it { expect(report).to include('max jobs for repo svenfuchs/gem-release by repo_settings: 2') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 2') }
  end

  describe 'with a default limit 1 and a repo settings limit 5' do
    before { config.limit.default = 1 }
    before { create_jobs(7, owner, :created, true) }
    before { create_jobs(3, owner, :started, false) }
    before { FactoryGirl.create(:subscription, selected_plan: :seven, valid_to: Time.now.utc, owner_type: owner.class.name, owner_id: owner.id) }
    before { repo.settings.update_attributes!(maximum_number_of_builds: 5) }
    before { subject }

    it { expect(subject.size).to eq 2 }
    it { expect(report).to include('max jobs for user svenfuchs by plan: 7 (svenfuchs)') }
    it { expect(report).to include('max jobs for repo svenfuchs/gem-release by repo_settings: 5') }
    it { expect(report).to include('user svenfuchs: total: 7, running: 3, queueable: 2') }
  end

  describe 'with a by_queue limit of 2' do
    before { create_jobs(9, owner, :created, true, repo, 'builds.osx') }
    before { create_jobs(1, owner, :created, true, repo, 'builds.docker') }
    before { config.limit.default = 99 }
    before { ENV['BY_QUEUE_LIMIT'] = "#{owner.login}=2" }
    before { ENV['BY_QUEUE_NAME'] = 'builds.osx' }
    after  { ENV.delete('BY_QUEUE_LIMIT') }
    after  { ENV.delete('BY_QUEUE_NAME') }
    before { subject }

    it { expect(subject.size).to eq 3 }
    it { expect(report).to include('max jobs for user svenfuchs by queue builds.osx: 2') }
    it { expect(report).to include('user svenfuchs: total: 10, running: 0, queueable: 3') }
  end

  describe 'with a by_queue limit of 2 and a repo limit of 3 on another repo' do
    let(:other) { FactoryGirl.create(:repo, github_id: 2) }
    before { create_jobs(9, owner, :created, true, repo, 'builds.osx') }
    before { create_jobs(5, owner, :created, true, other, 'builds.docker') }
    before { config.limit.default = 99 }
    before { other.settings.update_attributes!(maximum_number_of_builds: 3) }
    before { ENV['BY_QUEUE_LIMIT'] = "#{owner.login}=2" }
    before { ENV['BY_QUEUE_NAME'] = 'builds.osx' }
    after  { ENV.delete('BY_QUEUE_LIMIT') }
    after  { ENV.delete('BY_QUEUE_NAME') }
    before { subject }

    it { expect(subject.size).to eq 5 }
    it { expect(report).to include('max jobs for user svenfuchs by queue builds.osx: 2') }
    it { expect(report).to include('user svenfuchs: total: 14, running: 0, queueable: 5') }
  end

  describe 'delegated accounts' do
    let(:carla) { FactoryGirl.create(:user, login: 'carla') }

    before { create_jobs(3, owner, :created, true) }
    before { create_jobs(3, org,   :created, true) }
    before { create_jobs(1, owner, :started, false) }
    before { create_jobs(1, org,   :started, false) }

    before { config.limit.delegate = { owner.login => org.login, carla.login => org.login } }

    describe 'with one subscription' do
      before { FactoryGirl.create(:subscription, selected_plan: :seven, valid_to: Time.now.utc, owner_type: org.class.name, owner_id: org.id) }
      before { subject }

      it { expect(subject.size).to eq 5 }
      it { expect(subject.map(&:owner).map(&:login)).to eq ['svenfuchs'] * 3 + ['travis-ci'] * 2 }
      it { expect(report).to include('max jobs for user svenfuchs by plan: 7 (travis-ci)') }
      it { expect(report).to include('user carla, user svenfuchs, org travis-ci: total: 6, running: 2, queueable: 5') }
    end

    describe 'with multiple subscriptions' do
      before { FactoryGirl.create(:subscription, selected_plan: :one, valid_to: Time.now.utc, owner_type: owner.class.name, owner_id: owner.id) }
      before { FactoryGirl.create(:subscription, selected_plan: :seven, valid_to: Time.now.utc, owner_type: org.class.name, owner_id: org.id) }
      before { subject }

      it { expect(subject.size).to eq 6 }
      it { expect(subject.map(&:owner).map(&:login)).to eq ['svenfuchs'] * 3 + ['travis-ci'] * 3 }
      it { expect(report).to include('max jobs for user svenfuchs by plan: 8 (svenfuchs, travis-ci)') }
      it { expect(report).to include('user carla, user svenfuchs, org travis-ci: total: 6, running: 2, queueable: 6') }
    end
  end

  describe 'stages' do
    before { ENV['BUILD_STAGES'] = 'true' }
    after  { ENV['BUILD_STAGES'] = nil }

    let(:one) { FactoryGirl.create(:stage, number: 1) }
    let(:two) { FactoryGirl.create(:stage, number: 2) }

    before { create_jobs(1, owner, :created, nil, nil, '1.1', one) }
    before { create_jobs(1, owner, :created, nil, nil, '1.2', one) }
    before { create_jobs(1, owner, :created, nil, nil, '2.1', two) }
    before { config.limit.default = 5 }
    before { subject }

    it { expect(subject.size).to eq 2 }
    it { expect(report).to include("jobs for build #{build.id} limited at stage: 1 (queueable: 2)") }
  end
end
