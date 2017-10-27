describe Travis::Scheduler::Limit::Jobs do
  let(:org)     { FactoryGirl.create(:org, login: 'travis-ci') }
  let(:repo)    { FactoryGirl.create(:repo, owner: owner) }
  let(:build)   { FactoryGirl.create(:build) }
  let!(:owner)  { FactoryGirl.create(:user, login: 'svenfuchs') }
  let(:owners)  { Travis::Owners.group(data, config.to_h) }
  let(:context) { Travis::Scheduler.context }
  let(:redis)   { context.redis }
  let(:config)  { context.config }
  let(:data)    { { owner_type: 'User', owner_id: owner.id } }
  let(:limit)   { described_class.new(context, owners) }
  let(:report)  { limit.reports }

  env USE_QUEUEABLE_JOBS: true

  before  { config.limit.trial = nil }
  before  { config.limit.default = 1 }
  before  { config.plans = { one: 1, two: 2, seven: 7, ten: 10 } }
  subject { limit.run; limit.selected }

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

  describe 'with a boost limit 2' do
    before { create_jobs(3) }
    before { redis.set("scheduler.owner.limit.#{owner.login}", 2) }
    before { subject }

    it { expect(subject.size).to eq 2 }
    it { expect(report).to include('max jobs for user svenfuchs by boost: 2') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 2') }
  end

  describe 'with a subscription limit 1' do
    before { create_jobs(3) }
    before { FactoryGirl.create(:subscription, valid_to: Time.now.utc, owner_type: owner.class.name, owner_id: owner.id, selected_plan: :one) }
    before { subject }

    it { expect(subject.size).to eq 1 }
    it { expect(report).to include('max jobs for user svenfuchs by plan: 1 (svenfuchs)') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 1') }
  end

  describe 'with a custom config limit unlimited' do
    before { create_jobs(3) }
    before { config.limit.by_owner[owner.login] = -1 }
    before { subject }

    it { expect(subject.size).to eq 3 }
    it { expect(report).to include('max jobs for user svenfuchs by unlimited: true') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 3') }
  end

  describe 'with a custom config limit 1' do
    before { create_jobs(3) }
    before { config.limit.by_owner[owner.login] = 1 }
    before { subject }

    it { expect(subject.size).to eq 1 }
    it { expect(report).to include('max jobs for user svenfuchs by config: 1') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 1') }
  end

  describe 'with a trial' do
    before { create_jobs(3) }
    before { config.limit.trial = 2 }
    before { context.redis.set("trial:#{owner.login}", 5) }
    before { subject }

    it { expect(subject.size).to eq 2 }
    it { expect(report).to include('max jobs for user svenfuchs by trial: 2') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 2') }
  end

  describe 'with a default limit 1' do
    before { create_jobs(3) }
    before { config.limit.default = 1 }
    before { subject }

    it { expect(subject.size).to eq 1 }
    it { expect(report).to include('max jobs for user svenfuchs by default: 1') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 1') }
  end

  describe 'with a default limit 5 and a repo settings limit 2' do
    before { config.limit.default = 5 }
    before { create_jobs(3) }
    before { repo.settings.update_attributes!(maximum_number_of_builds: 2) }
    before { subject }

    it { expect(subject.size).to eq 2 }
    it { expect(report).to include('max jobs for repo svenfuchs/gem-release by repo_settings: 2') }
    it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 2') }
  end

  describe 'with a default limit 1 and a repo settings limit 5' do
    before { config.limit.default = 1 }
    before { create_jobs(7, state: :created) }
    before { create_jobs(3, state: :started) }
    before { FactoryGirl.create(:subscription, selected_plan: :seven, valid_to: Time.now.utc, owner_type: owner.class.name, owner_id: owner.id) }
    before { repo.settings.update_attributes!(maximum_number_of_builds: 5) }
    before { subject }

    it { expect(subject.size).to eq 2 }
    it { expect(report).to include('max jobs for user svenfuchs by plan: 7 (svenfuchs)') }
    it { expect(report).to include('max jobs for repo svenfuchs/gem-release by repo_settings: 5') }
    it { expect(report).to include('user svenfuchs: total: 7, running: 3, queueable: 2') }
  end

  describe 'with no by_queue config being given (enterprise)' do
    before { create_jobs(9, queue: 'builds.osx') }
    before { create_jobs(1, queue: 'builds.docker') }
    before { config.limit.default = 99 }
    before { subject }

    it { expect(subject.size).to eq 10 }
    it { expect(report).to include('user svenfuchs: total: 10, running: 0, queueable: 10') }
  end

  describe 'with a default by_queue limit of 2 (org)' do
    env BY_QUEUE_NAME: 'builds.osx'
    env BY_QUEUE_DEFAULT: 2

    before { create_jobs(9, queue: 'builds.osx') }
    before { create_jobs(1, queue: 'builds.docker') }
    before { config.limit.default = 99 }
    before { subject }

    it { expect(subject.size).to eq 3 }
    it { expect(report).to include('max jobs for user svenfuchs by queue builds.osx: 2') }
    it { expect(report).to include('user svenfuchs: total: 10, running: 0, queueable: 3') }
  end

  describe 'with a queue name set, but now default or owner config given (com)' do
    env BY_QUEUE_NAME: 'builds.osx'

    before { create_jobs(9, queue: 'builds.osx') }
    before { create_jobs(1, queue: 'builds.docker') }
    before { config.limit.default = 99 }
    before { ENV['BY_QUEUE_NAME'] = 'builds.osx' }
    after  { ENV.delete('BY_QUEUE_NAME') }
    before { subject }

    it { expect(subject.size).to eq 10 }
    it { expect(report).to include('user svenfuchs: total: 10, running: 0, queueable: 10') }
  end

  describe 'with a by_queue limit of 2 for the owner' do
    env BY_QUEUE_NAME: 'builds.osx'
    env BY_QUEUE_LIMIT: 'svenfuchs=2'

    before { create_jobs(9, queue: 'builds.osx') }
    before { create_jobs(1, queue: 'builds.docker') }
    before { config.limit.default = 99 }
    before { subject }

    it { expect(subject.size).to eq 3 }
    it { expect(report).to include('max jobs for user svenfuchs by queue builds.osx: 2') }
    it { expect(report).to include('user svenfuchs: total: 10, running: 0, queueable: 3') }
  end

  describe 'with a by_queue limit of 2 for the owner, and a default given' do
    env BY_QUEUE_NAME: 'builds.osx'
    env BY_QUEUE_LIMIT: 'svenfuchs=2'
    env BY_QUEUE_DEFAULT: 2

    before { create_jobs(9, queue: 'builds.osx') }
    before { create_jobs(1, queue: 'builds.docker') }
    before { config.limit.default = 99 }
    before { subject }

    it { expect(subject.size).to eq 3 }
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
    before { subject }

    it { expect(subject.size).to eq 5 }
    it { expect(report).to include('max jobs for user svenfuchs by queue builds.osx: 2') }
    it { expect(report).to include('user svenfuchs: total: 14, running: 0, queueable: 5') }
  end

  describe 'with a by_queue limit for the owner and jobs created for a different queue' do
    env BY_QUEUE_NAME: 'builds.osx'
    env BY_QUEUE_LIMIT: 'svenfuchs=2'

    before { create_jobs(9, queue: 'builds.docker') }
    before { create_jobs(1, queue: 'builds.osx') }
    before { config.limit.default = 5 }
    before { subject }

    it { expect(subject.size).to eq 5 }
    it { expect(report).to include('max jobs for user svenfuchs by default: 5') }
    it { expect(report).to include('user svenfuchs: total: 10, running: 0, queueable: 5') }
  end

  describe 'delegated accounts' do
    let(:carla) { FactoryGirl.create(:user, login: 'carla') }

    before { create_jobs(3, owner: owner, state: :created, queueable: true) }
    before { create_jobs(3, owner: org,   state: :created, queueable: true) }
    before { create_jobs(1, owner: owner, state: :started, queueable: false) }
    before { create_jobs(1, owner: org,   state: :started, queueable: false) }

    before { config.limit.delegate = { owner.login => org.login, carla.login => org.login } }

    describe 'with one subscription' do
      before { FactoryGirl.create(:subscription, selected_plan: :seven, valid_to: Time.now.utc, owner_type: org.class.name, owner_id: org.id) }
      before { subject }

      it { expect(subject.size).to eq 5 }
      it { expect(subject.map(&:owner).map(&:login)).to eq ['svenfuchs'] * 3 + ['travis-ci'] * 2 }
      it { expect(report).to include('max jobs for user svenfuchs by plan: 7 (travis-ci)') }
      it { expect(report).to include('user svenfuchs, user carla, org travis-ci: total: 6, running: 2, queueable: 5') }
    end

    describe 'with multiple subscriptions' do
      before { FactoryGirl.create(:subscription, selected_plan: :one, valid_to: Time.now.utc, owner_type: owner.class.name, owner_id: owner.id) }
      before { FactoryGirl.create(:subscription, selected_plan: :seven, valid_to: Time.now.utc, owner_type: org.class.name, owner_id: org.id) }
      before { subject }

      it { expect(subject.size).to eq 6 }
      it { expect(subject.map(&:owner).map(&:login)).to eq ['svenfuchs'] * 3 + ['travis-ci'] * 3 }
      it { expect(report).to include('max jobs for user svenfuchs by plan: 8 (svenfuchs, travis-ci)') }
      it { expect(report).to include('user svenfuchs, user carla, org travis-ci: total: 6, running: 2, queueable: 6') }
    end
  end

  describe 'stages' do
    let(:one) { FactoryGirl.create(:stage, number: 1) }
    let(:two) { FactoryGirl.create(:stage, number: 2) }
    let(:three) { FactoryGirl.create(:stage, number: 3) }

    before { create_jobs(1, owner: owner, state: :created, stage: one, stage_number: '1.1') }
    before { create_jobs(1, owner: owner, state: :created, stage: one, stage_number: '1.2') }
    before { create_jobs(1, owner: owner, state: :created, stage: two, stage_number: '2.1') }
    before { create_jobs(1, owner: owner, state: :created, stage: three, stage_number: '10.1') }
    before { config.limit.default = 5 }

    describe 'queueing' do
      before { subject }
      it { expect(subject.size).to eq 2 }
      it { expect(report).to include("jobs for build id=#{build.id} repo=#{repo.slug} limited at stage: 1 (queueable: 2)") }
    end

    describe 'ordering' do
      before { one.jobs.update_all(state: :passed) }
      before { Queueable.where(job_id: one.jobs.pluck(:id)).delete_all }
      it { expect(subject.first.stage_number).to eq '2.1' }
    end
  end

  describe 'The Merge mode' do
    feature :public_mode, owner: 'svenfuchs'

    before { config.limit.public  = 3 } # we allow up to 3 extra public jobs
    before { config.limit.default = 1 } # we allow 1 public or private job by default

    describe 'no running jobs, 2 public, 2 private, and 2 public jobs waiting, no subscription' do
      before { create_jobs(2, private: false) }
      before { create_jobs(2, private: true) }
      before { create_jobs(2, private: false) }

      it { expect(subject.size).to eq 4 }
      it { expect(subject.map(&:public?)).to eq [true, true, false, true] }
    end

    describe 'no running jobs, 2 public and 4 private jobs waiting, no subscription' do
      before { create_jobs(2, private: false) }
      before { create_jobs(4, private: true) }

      it { expect(subject.size).to eq 3 }
      it { expect(subject.map(&:public?)).to eq [true, true, false] }
    end

    describe 'no running jobs, 4 public and 4 private jobs waiting, no subscription' do
      before { create_jobs(4, private: false) }
      before { create_jobs(4, private: true) }

      it { expect(subject.size).to eq 4 }
      it { expect(subject.map(&:public?)).to eq [true, true, true, true] }
    end

    describe 'no running jobs, 4 private and 4 public jobs waiting, no subscription' do
      before { create_jobs(4, private: true) }
      before { create_jobs(4, private: false) }

      it { expect(subject.size).to eq 4 }
      it { expect(subject.map(&:public?)).to eq [false, true, true, true] }
    end

    describe 'no running jobs, 4 private and 4 public jobs waiting, two jobs subscription' do
      before { FactoryGirl.create(:subscription, selected_plan: :two, valid_to: Time.now.utc, owner_type: owner.class.name, owner_id: owner.id) }
      before { create_jobs(4, private: true) }
      before { create_jobs(4, private: false) }

      it { expect(subject.size).to eq 5 }
      it { expect(subject.map(&:public?)).to eq [false, false, true, true, true] }
    end

    describe '2 running public jobs, 2 public and 2 private jobs waiting, no subscription' do
      before { create_jobs(2, private: false, state: :started) }
      before { create_jobs(2, private: false) }
      before { create_jobs(2, private: true) }

      it { expect(subject.size).to eq 2 }
      it { expect(subject.map(&:public?)).to eq [true, true] }
    end

    describe '1 running private job, 2 public and 2 private jobs waiting, no subscription' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(2, private: false) }
      before { create_jobs(2, private: true) }

      it { expect(subject.size).to eq 2 }
      it { expect(subject.map(&:public?)).to eq [true, true] }
    end

    describe '1 running private job, 2 private and 2 public jobs waiting, no subscription' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(2, private: true) }
      before { create_jobs(2, private: false) }

      it { expect(subject.size).to eq 2 }
      it { expect(subject.map(&:public?)).to eq [true, true] }
    end
  end
end
