describe Travis::Scheduler::Limit::Jobs do
  let(:org)     { FactoryGirl.create(:org, login: 'travis-ci') }
  let(:repo)    { FactoryGirl.create(:repo) }
  let(:owner)   { FactoryGirl.create(:user) }
  let(:owners)  { Travis::Scheduler::Model::Owners.new(data, config) }
  let(:context) { Travis::Scheduler.context }
  let(:redis)   { context.redis }
  let(:config)  { context.config }
  let(:data)    { { owner_type: 'User', owner_id: owner.id } }
  let(:limit)   { described_class.new(context, owners) }
  let(:report)  { limit.reports }

  before  { config.limit.default = 5 }
  before  { config.plans = { one: 1, seven: 7, ten: 10 } }
  subject { limit.run; limit.jobs }

  def create_jobs(count, owner, state)
    1.upto(count) { FactoryGirl.create(:job, repository: repo, owner: owner, state: state) }
  end

  describe 'with a boost limit 2' do
    before { create_jobs(3, owner, :created) }
    before { redis.set("scheduler.owner.limit.#{owner.login}", 2) }
    before { subject }

    it { expect(subject.size).to eq 2 }
    it { expect(report).to include('max jobs for svenfuchs by boost: 2') }
    it { expect(report).to include('svenfuchs: total: 3, running: 0, queueable: 2') }
  end

  describe 'with a subscription limit 1' do
    before { create_jobs(3, owner, :created) }
    before { FactoryGirl.create(:subscription, valid_to: Time.now.utc, owner_type: owner.class.name, owner_id: owner.id, selected_plan: :one) }
    before { subject }

    it { expect(subject.size).to eq 1 }
    it { expect(report).to include('max jobs for svenfuchs by plan: 1 (svenfuchs)') }
    it { expect(report).to include('svenfuchs: total: 3, running: 0, queueable: 1') }
  end

  describe 'with a custom config limit unlimited' do
    before { create_jobs(3, owner, :created) }
    before { config.limit.by_owner[owner.login] = -1 }
    before { subject }

    it { expect(subject.size).to eq 3 }
    it { expect(report).to include('max jobs for svenfuchs by unlimited: true') }
    it { expect(report).to include('svenfuchs: total: 3, running: 0, queueable: 3') }
  end

  describe 'with a custom config limit 1' do
    before { create_jobs(3, owner, :created) }
    before { config.limit.by_owner[owner.login] = 1 }
    before { subject }

    it { expect(subject.size).to eq 1 }
    it { expect(report).to include('max jobs for svenfuchs by config: 1') }
    it { expect(report).to include('svenfuchs: total: 3, running: 0, queueable: 1') }
  end

  describe 'with a default limit 1' do
    before { create_jobs(3, owner, :created) }
    before { config.limit.default = 1 }
    before { subject }

    it { expect(subject.size).to eq 1 }
    it { expect(report).to include('max jobs for svenfuchs by default: 1') }
    it { expect(report).to include('svenfuchs: total: 3, running: 0, queueable: 1') }
  end

  describe 'with a repo settings limit 1' do
    before { create_jobs(3, owner, :created) }
    before { repo.settings.update_attributes!(maximum_number_of_builds: 1) }
    before { subject }

    it { expect(subject.size).to eq 1 }
    it { expect(report).to include('max jobs for svenfuchs/gem-release by repo_settings: 1') }
    it { expect(report).to include('svenfuchs: total: 3, running: 0, queueable: 1') }
  end

  describe 'with a repo settings limit 5' do
    before { create_jobs(7, owner, :created) }
    before { create_jobs(3, owner, :started) }
    before { FactoryGirl.create(:subscription, selected_plan: :seven, valid_to: Time.now.utc, owner_type: owner.class.name, owner_id: owner.id) }
    before { repo.settings.update_attributes!(maximum_number_of_builds: 5) }
    before { subject }

    it { expect(subject.size).to eq 2 }
    it { expect(report).to include('max jobs for svenfuchs by plan: 7 (svenfuchs)') }
    it { expect(report).to include('max jobs for svenfuchs/gem-release by repo_settings: 5') }
    it { expect(report).to include('svenfuchs: total: 7, running: 3, queueable: 2') }
  end

  describe 'delegated accounts' do
    let(:carla) { FactoryGirl.create(:user, login: 'carla') }

    before { create_jobs(3, owner, :created) }
    before { create_jobs(3, org,   :created) }
    before { create_jobs(1, owner, :started) }
    before { create_jobs(1, org,   :started) }

    before { config.limit.delegate = { owner.login => org.login, carla.login => org.login } }

    describe 'with one subscription' do
      before { FactoryGirl.create(:subscription, selected_plan: :seven, valid_to: Time.now.utc, owner_type: org.class.name, owner_id: org.id) }
      before { subject }

      it { expect(subject.size).to eq 5 }
      it { expect(subject.map(&:owner).map(&:login)).to eq ['svenfuchs'] * 3 + ['travis-ci'] * 2 }
      it { expect(report).to include('max jobs for svenfuchs by plan: 7 (travis-ci)') }
      it { expect(report).to include('carla, svenfuchs, travis-ci: total: 6, running: 2, queueable: 5') }
    end

    describe 'with multiple subscriptions' do
      before { FactoryGirl.create(:subscription, selected_plan: :one, valid_to: Time.now.utc, owner_type: owner.class.name, owner_id: owner.id) }
      before { FactoryGirl.create(:subscription, selected_plan: :seven, valid_to: Time.now.utc, owner_type: org.class.name, owner_id: org.id) }
      before { subject }

      it { expect(subject.size).to eq 6 }
      it { expect(subject.map(&:owner).map(&:login)).to eq ['svenfuchs'] * 3 + ['travis-ci'] * 3 }
      it { expect(report).to include('max jobs for svenfuchs by plan: 8 (svenfuchs, travis-ci)') }
      it { expect(report).to include('carla, svenfuchs, travis-ci: total: 6, running: 2, queueable: 6') }
    end
  end
end
