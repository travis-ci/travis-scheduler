describe Travis::Scheduler::Limit::Jobs, 'org' do
  let(:org)      { FactoryGirl.create(:org, login: 'travis-ci') }
  let(:repo)     { FactoryGirl.create(:repo, owner: owner) }
  let(:build)    { FactoryGirl.create(:build) }
  let!(:owner)   { FactoryGirl.create(:user, login: 'svenfuchs') }
  let(:owners)   { Travis::Owners.group(data, config.to_h) }
  let(:context)  { Travis::Scheduler.context }
  let(:redis)    { context.redis }
  let(:config)   { context.config }
  let(:data)     { { owner_type: 'User', owner_id: owner.id } }
  let(:limit)    { described_class.new(context, owners) }
  let(:report)   { limit.reports }
  let(:selected) { limit.selected.size }
  let(:waiting)  { limit.waiting_by_owner }
  let(:run)      { limit.run; nil }

  env USE_QUEUEABLE_JOBS: true

  before { config.limit.trial = nil }
  before { config.limit.default = 5 }
  before { config.plans = { one: 1, two: 2, four: 4, seven: 7, ten: 10 } }
  before { config.site = 'org' }

  def create_jobs(count, attrs = {})
    defaults = {
      repository: repo,
      owner: owner,
      source: build,
      state: :created,
      queueable: true,
      private: false
    }
    1.upto(count) { FactoryGirl.create(:job, defaults.merge(attrs)) }
  end

  def subscription(plan)
    FactoryGirl.create(:subscription, selected_plan: plan, valid_to: Time.now.utc, owner_type: owner.class.name, owner_id: owner.id)
  end

  before { config.limit.public = 3 }

  describe 'with a boost limit 2' do
    before { redis.set("scheduler.owner.limit.#{owner.login}", 2) }
    before { create_jobs(4) }
    before { run }

    it { expect(selected).to eq 2 }
    it { expect(report).to include('max jobs for user svenfuchs by boost: 2') }
    it { expect(report).to include('user svenfuchs: total: 4, running: 0, queueable: 2') }
    it { expect(report).to include('jobs waiting for svenfuchs: svenfuchs/gem-release=2') }
    it { expect(waiting).to eq 2 }
  end

  describe 'with a custom config limit unlimited' do
    before { config.limit.by_owner[owner.login] = -1 }
    before { create_jobs(3) }
    before { run }

    it { expect(selected).to eq 3 }
    it { expect(report).to include('max jobs for user svenfuchs by unlimited: true') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 3') }
    it { expect(limit.waiting_by_owner).to eq 0 }
  end

  describe 'with a custom config limit 1' do
    before { config.limit.by_owner[owner.login] = 1 }
    before { create_jobs(3) }
    before { run }

    it { expect(selected).to eq 1 }
    it { expect(report).to include('max jobs for user svenfuchs by config: 1') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 1') }
    it { expect(limit.waiting_by_owner).to eq 2 }
  end

  describe 'with a default limit 1' do
    before { config.limit.default = 1 }
    before { create_jobs(3) }
    before { run }

    it { expect(selected).to eq 1 }
    it { expect(report).to include('max jobs for user svenfuchs by default: 1') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 1') }
    it { expect(limit.waiting_by_owner).to eq 2 }
  end

  describe 'with a default limit 5 and a repo settings limit 2' do
    before { config.limit.default = 5 }
    before { repo.settings.update_attributes!(maximum_number_of_builds: 2) }
    before { create_jobs(3) }
    before { run }

    it { expect(selected).to eq 2 }
    it { expect(report).to include('max jobs for repo svenfuchs/gem-release by repo_settings: 2') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 2') }
    it { expect(limit.waiting_by_owner).to eq 0 }
  end

  describe 'with a default limit 5, and a repo setting of 3' do
    before { config.limit.default = 5 }
    before { repo.settings.update_attributes!(maximum_number_of_builds: 3) }
    before { create_jobs(1, state: :started) }
    before { create_jobs(4, state: :created) }
    before { run }

    it { expect(selected).to eq 2 }
    it { expect(report).to include('max jobs for repo svenfuchs/gem-release by repo_settings: 3') }
    it { expect(report).to include('user svenfuchs: total: 4, running: 1, queueable: 2') }
    it { expect(limit.waiting_by_owner).to eq 0 }
  end

  describe 'with no by_queue config being given and a two jobs plan' do
    before { create_jobs(3, queue: 'builds.osx') }
    before { create_jobs(1, queue: 'builds.docker') }
    before { run }

    it { expect(selected).to eq 4 }
    it { expect(report).to include('user svenfuchs: total: 4, running: 0, queueable: 4') }
  end

  describe 'stages' do
    describe 'with public jobs only' do
      let(:one) { FactoryGirl.create(:stage, number: 1) }
      let(:two) { FactoryGirl.create(:stage, number: 2) }
      let(:three) { FactoryGirl.create(:stage, number: 3) }

      before { create_jobs(1, owner: owner, state: :created, stage: one, stage_number: '1.1') }
      before { create_jobs(1, owner: owner, state: :created, stage: one, stage_number: '1.2') }
      before { create_jobs(1, owner: owner, state: :created, stage: two, stage_number: '2.1') }
      before { create_jobs(1, owner: owner, state: :created, stage: three, stage_number: '10.1') }
      before { config.limit.default = 5 }

      describe 'queueing' do
        before { run }
        it { expect(selected).to eq 2 }
        it { expect(report).to include("jobs for build id=#{build.id} repo=#{repo.slug} limited at stage: 1 (queueable: 2)") }
      end

      describe 'ordering' do
        before { one.jobs.update_all(state: :passed) }
        before { Queueable.where(job_id: one.jobs.pluck(:id)).delete_all }
        before { run }
        it { expect(limit.selected.first.stage_number).to eq '2.1' }
      end
    end
  end

  describe 'with a by_queue limit of 2 for the owner' do
    env BY_QUEUE_NAME: 'builds.osx'
    env BY_QUEUE_LIMIT: 'svenfuchs=2'

    before { create_jobs(9, queue: 'builds.osx') }
    before { create_jobs(1, queue: 'builds.docker') }
    before { config.limit.default = 99 }
    before { run }

    it { expect(selected).to eq 3 }
    it { expect(report).to include('max jobs for user svenfuchs by queue builds.osx: 2') }
    it { expect(report).to include('user svenfuchs: total: 10, running: 0, queueable: 3') }
  end

  describe 'with a by_queue limit of 2 for the owner and a repo limit of 3 on another repo' do
    env BY_QUEUE_NAME: 'builds.osx'
    env BY_QUEUE_LIMIT: 'svenfuchs=2'
    env BY_QUEUE_DEFAULT: 2

    let(:other) { FactoryGirl.create(:repo, github_id: 2) }
    before { create_jobs(9, repository: repo, queue: 'builds.osx') }
    before { create_jobs(5, repository: other, queue: 'builds.docker') }
    before { config.limit.default = 99 }
    before { other.settings.update_attributes!(maximum_number_of_builds: 3) }
    before { run }

    it { expect(selected).to eq 5 }
    it { expect(report).to include('max jobs for user svenfuchs by queue builds.osx: 2') }
    it { expect(report).to include('user svenfuchs: total: 14, running: 0, queueable: 5') }
  end

  describe 'with a by_queue limit for the owner and jobs created for a different queue' do
    env BY_QUEUE_NAME: 'builds.osx'
    env BY_QUEUE_LIMIT: 'svenfuchs=2'

    before { create_jobs(9, queue: 'builds.docker') }
    before { create_jobs(1, queue: 'builds.osx') }
    before { config.limit.default = 5 }
    before { run }

    it { expect(selected).to eq 5 }
    it { expect(report).to include('max jobs for user svenfuchs by default: 5') }
    it { expect(report).to include('user svenfuchs: total: 10, running: 0, queueable: 5') }
    it { expect(limit.waiting_by_owner).to eq 5 }
  end
end
