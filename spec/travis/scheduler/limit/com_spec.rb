describe Travis::Scheduler::Limit::Jobs, 'com (github apps)' do
  let(:org)      { FactoryGirl.create(:org, login: 'travis-ci') }
  let(:repo)     { FactoryGirl.create(:repo, owner: owner, migrated_at: 1.hour.ago) }
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
  before { config.limit.default = 1 }
  before { config.plans = { one: 1, two: 2, four: 4, seven: 7, ten: 10 } }
  before { config.site = 'com' }

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

  def subscription(plan, owner = self.owner)
    FactoryGirl.create(:subscription, selected_plan: plan, valid_to: Time.now.utc, owner_type: owner.class.name, owner_id: owner.id)
  end

  before { config.limit.public = 3 }

  describe 'with a boost limit 2' do
    before { redis.set("scheduler.owner.limit.#{owner.login}", 2) }

    describe 'with private jobs only' do
      before { create_jobs(4, private: true) }
      before { run }

      it { expect(selected).to eq 2 }
      it { expect(report).to include('max jobs for user svenfuchs by boost: 2') }
      it { expect(report).to include('user svenfuchs: total: 4, running: 0, queueable: 2') }
      it { expect(report).to include('jobs waiting for svenfuchs: svenfuchs/gem-release=2') }
      it { expect(waiting).to eq 2 }
    end

    describe 'with public jobs only' do
      before { create_jobs(4, private: false) }
      before { run }

      it { expect(selected).to eq 2 }
      it { expect(report).to include('max jobs for user svenfuchs by boost: 2') }
      it { expect(report).to include('user svenfuchs: total: 4, running: 0, queueable: 2') }
      it { expect(report).to include('jobs waiting for svenfuchs: svenfuchs/gem-release=2') }
      it { expect(waiting).to eq 2 }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(1, private: true) }
      before { create_jobs(1, private: false) }
      before { run }

      it { expect(selected).to eq 2 }
      it { expect(report).to include('max jobs for user svenfuchs by boost: 2') }
      it { expect(report).to include('user svenfuchs: total: 2, running: 0, queueable: 2') }
      it { expect(waiting).to eq 0 }
    end
  end

  describe 'with a two jobs plan' do
    before { subscription(:two) }

    describe 'with private jobs only' do
      before { create_jobs(1, state: :started, private: true) }
      before { create_jobs(2, state: :created, private: true) }
      before { run }

      it { expect(selected).to eq 2 }
      it { expect(report).to include('max jobs for user svenfuchs by plan: 3 (svenfuchs)') }
      it { expect(report).to include('user svenfuchs: total: 2, running: 1, queueable: 2') }
      it { expect(limit.waiting_by_owner).to eq 0 }
    end

    describe 'with public jobs only' do
      before { create_jobs(1, state: :started, private: false) }
      before { create_jobs(2, state: :created, private: false) }
      before { subscription(:two) }
      before { run }

      it { expect(selected).to eq 2 }
      it { expect(report).to include('max jobs for user svenfuchs by plan: 6 (svenfuchs)') } # TODO fix log output?
      it { expect(report).to include('user svenfuchs: total: 2, running: 1, queueable: 2') }
      it { expect(limit.waiting_by_owner).to eq 0 }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(1, state: :started, private: true) }
      before { create_jobs(1, state: :started, private: false) }
      before { create_jobs(2, state: :created, private: true) }
      before { create_jobs(2, state: :created, private: false) }
      before { subscription(:two) }
      before { run }

      it { expect(selected).to eq 4 }
      it { expect(report).to include('max jobs for user svenfuchs by plan: 3 (svenfuchs)') }
      it { expect(report).to include('user svenfuchs: total: 4, running: 2, queueable: 4') }
      it { expect(limit.waiting_by_owner).to eq 0 }
    end

    describe 'with migrated jobs' do
      before { create_jobs(1, state: :started, private: false) }
      before { create_jobs(1, state: :created, private: false) }

      # a job that was migrated from org, shouldn't count towards running jobs
      before { create_jobs(1, private: false, state: :started, org_id: 10) }
      # a job that was migrated from org, but restarted after migration, should
      # be counted towards running jobs
      before { create_jobs(1, private: false, state: :started, org_id: 11, restarted_at: Time.now) }
      # a job that was migrated as queueable, shouldn't be queued
      before { create_jobs(1, private: false, state: :created, org_id: 12) }
      # a job that was migrated and restarted
      before { create_jobs(1, private: false, state: :created, org_id: 13, restarted_at: Time.now) }
      before { run }

      it { expect(selected).to eq 2 }
      it { expect(report).to include('user svenfuchs: total: 2, running: 2, queueable: 2') }
    end
  end

  describe 'with a custom config limit unlimited' do
    before { config.limit.by_owner[owner.login] = -1 }

    describe 'with private jobs only' do
      before { create_jobs(3, private: true) }
      before { run }

      it { expect(selected).to eq 3 }
      it { expect(report).to include('max jobs for user svenfuchs by unlimited: true') }
      it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 3') }
      it { expect(limit.waiting_by_owner).to eq 0 }
    end

    describe 'with public jobs only' do
      before { create_jobs(3, private: true) }
      before { run }

      it { expect(selected).to eq 3 }
      it { expect(report).to include('max jobs for user svenfuchs by unlimited: true') }
      it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 3') }
      it { expect(limit.waiting_by_owner).to eq 0 }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(3, private: true) }
      before { run }

      it { expect(selected).to eq 3 }
      it { expect(report).to include('max jobs for user svenfuchs by unlimited: true') }
      it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 3') }
      it { expect(limit.waiting_by_owner).to eq 0 }
    end
  end

  describe 'with a custom config limit 1' do
    before { config.limit.by_owner[owner.login] = 1 }

    describe 'with private jobs only' do
      before { create_jobs(3, private: true) }
      before { run }

      it { expect(selected).to eq 1 }
      it { expect(report).to include('max jobs for user svenfuchs by config: 1') }
      it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 1') }
      it { expect(limit.waiting_by_owner).to eq 2 }
    end

    describe 'with public jobs only' do
      before { create_jobs(3, private: true) }
      before { run }

      it { expect(selected).to eq 1 }
      it { expect(report).to include('max jobs for user svenfuchs by config: 1') }
      it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 1') }
      it { expect(limit.waiting_by_owner).to eq 2 }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(2, private: true) }
      before { create_jobs(2, private: false) }
      before { run }

      it { expect(selected).to eq 3 } # this definitely weird, but probably not used at all
      it { expect(report).to include('max jobs for user svenfuchs by config: 1') }
      it { expect(report).to include('user svenfuchs: total: 4, running: 0, queueable: 3') }
      it { expect(limit.waiting_by_owner).to eq 1 }
    end
  end

  describe 'with a trial' do
    before { config.limit.trial = 2 }
    before { context.redis.set("trial:#{owner.login}", 5) }

    describe 'with private jobs only' do
      before { create_jobs(3, private: true) }
      before { run }

      it { expect(selected).to eq 2 }
      it { expect(report).to include('max jobs for user svenfuchs by trial: 2') }
      it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 2') }
      it { expect(limit.waiting_by_owner).to eq 1 }
    end

    describe 'with public jobs only' do
      before { create_jobs(3, private: false) }
      before { run }

      it { expect(selected).to eq 3 }
      it { expect(report).to include('max jobs for user svenfuchs by trial: 5') } # TODO fix log output
      it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 3') }
      it { expect(limit.waiting_by_owner).to eq 0 }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(3, private: true) }
      before { create_jobs(3, private: false) }
      before { run }

      it { expect(selected).to eq 5 }
      it { expect(report).to include('max jobs for user svenfuchs by trial: 2') }
      it { expect(report).to include('user svenfuchs: total: 6, running: 0, queueable: 5') }
      it { expect(limit.waiting_by_owner).to eq 1 }
    end
  end

  describe 'with a default limit 1' do
    before { config.limit.default = 1 }

    describe 'with private jobs only' do
      before { create_jobs(3, private: true) }
      before { run }

      it { expect(selected).to eq 1 }
      it { expect(report).to include('max jobs for user svenfuchs by default: 1') }
      it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 1') }
      it { expect(limit.waiting_by_owner).to eq 2 }
    end

    describe 'with public jobs only' do
      before { create_jobs(3, private: false) }
      before { run }

      it { expect(selected).to eq 3 }
      it { expect(report).to include('max jobs for user svenfuchs by default: 4') }
      it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 3') }
      it { expect(limit.waiting_by_owner).to eq 0 }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(3, private: true) }
      before { create_jobs(3, private: false) }
      before { run }

      it { expect(selected).to eq 4 }
      it { expect(report).to include('max jobs for user svenfuchs by default: 1') }
      it { expect(report).to include('user svenfuchs: total: 6, running: 0, queueable: 4') }
      it { expect(limit.waiting_by_owner).to eq 2 }
    end
  end

  describe 'with a default limit 5 and a repo settings limit 2' do
    before { config.limit.default = 5 }
    before { repo.settings.update_attributes!(maximum_number_of_builds: 2) }

    describe 'with private jobs only' do
      before { create_jobs(3, private: true) }
      before { run }

      it { expect(selected).to eq 2 }
      it { expect(report).to include('max jobs for repo svenfuchs/gem-release by repo_settings: 2') }
      it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 2') }
      it { expect(limit.waiting_by_owner).to eq 0 }
    end

    describe 'with public jobs only' do
      before { create_jobs(3, private: false) }
      before { run }

      it { expect(selected).to eq 2 }
      it { expect(report).to include('max jobs for repo svenfuchs/gem-release by repo_settings: 2') }
      it { expect(report).to include('user svenfuchs: total: 3, running: 0, queueable: 2') }
      it { expect(limit.waiting_by_owner).to eq 0 }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(3, private: true) }
      before { create_jobs(3, private: false) }
      before { run }

      it { expect(selected).to eq 2 }
      it { expect(report).to include('max jobs for repo svenfuchs/gem-release by repo_settings: 2') }
      it { expect(report).to include('user svenfuchs: total: 6, running: 0, queueable: 2') }
      it { expect(limit.waiting_by_owner).to eq 0 }
    end
  end

  describe 'with a default limit 1, a four jobs plan, and a repo setting of 3' do
    before { subscription(:four) }
    before { repo.settings.update_attributes!(maximum_number_of_builds: 3) }

    describe 'with private jobs only' do
      before { create_jobs(1, state: :started, private: true) }
      before { create_jobs(4, state: :created, private: true) }
      before { run }

      it { expect(selected).to eq 2 }
      it { expect(report).to include('max jobs for user svenfuchs by plan: 5 (svenfuchs)') }
      it { expect(report).to include('max jobs for repo svenfuchs/gem-release by repo_settings: 3') }
      it { expect(report).to include('user svenfuchs: total: 4, running: 1, queueable: 2') }
      it { expect(limit.waiting_by_owner).to eq 0 } # TODO eh??? should be 2, no?
    end

    describe 'with public jobs only' do
      before { create_jobs(1, state: :started, private: false) }
      before { create_jobs(4, state: :created, private: false) }
      before { run }

      it { expect(selected).to eq 2 }
      it { expect(report).to include('max jobs for user svenfuchs by plan: 8 (svenfuchs)') } # TODO fix log output?
      it { expect(report).to include('max jobs for repo svenfuchs/gem-release by repo_settings: 3') }
      it { expect(report).to include('user svenfuchs: total: 4, running: 1, queueable: 2') }
      it { expect(limit.waiting_by_owner).to eq 0 }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(1, state: :started, private: true) }
      before { create_jobs(1, state: :started, private: false) }
      before { create_jobs(3, state: :created, private: true) }
      before { create_jobs(3, state: :created, private: false) }
      before { run }

      it { expect(selected).to eq 1 }
      it { expect(report).to include('max jobs for user svenfuchs by plan: 5 (svenfuchs)') }
      it { expect(report).to include('max jobs for repo svenfuchs/gem-release by repo_settings: 3') }
      it { expect(report).to include('user svenfuchs: total: 6, running: 2, queueable: 1') }
      it { expect(limit.waiting_by_owner).to eq 0 } # TODO eh???
    end
  end

  describe 'with no by_queue config being given and a two jobs plan' do
    describe 'with private jobs only' do
      before { create_jobs(3, private: true, queue: 'builds.osx') }
      before { create_jobs(1, private: true, queue: 'builds.docker') }
      before { subscription(:two) }
      before { run }

      it { expect(selected).to eq 3 }
      it { expect(report).to include('user svenfuchs: total: 4, running: 0, queueable: 3') }
    end

    describe 'with public jobs only' do
      before { create_jobs(3, private: false, queue: 'builds.osx') }
      before { create_jobs(1, private: false, queue: 'builds.docker') }
      before { run }

      it { expect(selected).to eq 4 }
      it { expect(report).to include('user svenfuchs: total: 4, running: 0, queueable: 4') }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(1, private: true, queue: 'builds.osx') }
      before { create_jobs(1, private: true, queue: 'builds.docker') }
      before { create_jobs(1, private: false, queue: 'builds.osx') }
      before { create_jobs(1, private: false, queue: 'builds.docker') }
      before { run }

      it { expect(selected).to eq 3 }
      it { expect(report).to include('user svenfuchs: total: 4, running: 0, queueable: 3') }
    end
  end

  describe 'delegated accounts' do
    describe 'with private jobs only' do
      let(:carla) { FactoryGirl.create(:user, login: 'carla') }

      before { create_jobs(1, owner: owner, state: :started, queueable: false, private: true) }
      before { create_jobs(1, owner: org,   state: :started, queueable: false, private: true) }
      before { create_jobs(3, owner: owner, state: :created, queueable: true, private: true) }
      before { create_jobs(3, owner: org,   state: :created, queueable: true, private: true) }

      before { config.limit.delegate = { owner.login => org.login, carla.login => org.login } }

      describe 'with one subscription' do
        before { subscription(:seven, org) }
        before { run }

        it { expect(selected).to eq 5 }
        it { expect(limit.selected.map(&:owner).map(&:login)).to eq ['svenfuchs'] * 3 + ['travis-ci'] * 2 }
        it { expect(report).to include('max jobs for user svenfuchs by plan: 7 (travis-ci)') }
        it { expect(report).to include('user svenfuchs, user carla, org travis-ci: total: 6, running: 2, queueable: 5') }
        it { expect(limit.waiting_by_owner).to eq 1 }
      end

      describe 'with multiple subscriptions' do
        before { subscription(:one, owner) }
        before { subscription(:seven, org) }
        before { run }

        it { expect(selected).to eq 6 }
        it { expect(limit.selected.map(&:owner).map(&:login)).to eq ['svenfuchs'] * 3 + ['travis-ci'] * 3 }
        it { expect(report).to include('max jobs for user svenfuchs by plan: 9 (svenfuchs, travis-ci)') }
        it { expect(report).to include('user svenfuchs, user carla, org travis-ci: total: 6, running: 2, queueable: 6') }
      end
    end

    describe 'with public jobs only' do
      let(:carla) { FactoryGirl.create(:user, login: 'carla') }

      before { create_jobs(1, owner: owner, state: :started, queueable: false, private: false) }
      before { create_jobs(1, owner: org,   state: :started, queueable: false, private: false) }
      before { create_jobs(3, owner: owner, state: :created, queueable: true, private: false) }
      before { create_jobs(3, owner: org,   state: :created, queueable: true, private: false) }

      before { config.limit.delegate = { owner.login => org.login, carla.login => org.login } }

      describe 'with one subscription' do
        before { subscription(:four, org) }
        before { run }

        it { expect(selected).to eq 5 }
        it { expect(limit.selected.map(&:owner).map(&:login)).to eq ['svenfuchs'] * 3 + ['travis-ci'] * 2 }
        it { expect(report).to include('max jobs for user svenfuchs by plan: 7 (travis-ci)') }
        it { expect(report).to include('user svenfuchs, user carla, org travis-ci: total: 6, running: 2, queueable: 5') }
        it { expect(limit.waiting_by_owner).to eq 1 }
      end

      describe 'with multiple subscriptions' do
        before { subscription(:one, owner) }
        before { subscription(:four, org) }
        before { run }

        it { expect(selected).to eq 6 }
        it { expect(limit.selected.map(&:owner).map(&:login)).to eq ['svenfuchs'] * 3 + ['travis-ci'] * 3 }
        it { expect(report).to include('max jobs for user svenfuchs by plan: 9 (svenfuchs, travis-ci)') } # TODO fix log output
        it { expect(report).to include('user svenfuchs, user carla, org travis-ci: total: 6, running: 2, queueable: 6') }
      end
    end

    describe 'for mixed public and private jobs' do
      let(:carla) { FactoryGirl.create(:user, login: 'carla') }

      before { create_jobs(1, owner: owner, state: :started, queueable: false, private: true) }
      before { create_jobs(1, owner: org,   state: :started, queueable: false, private: true) }
      before { create_jobs(3, owner: owner, state: :created, queueable: true, private: true) }
      before { create_jobs(3, owner: org,   state: :created, queueable: true, private: true) }

      before { config.limit.delegate = { owner.login => org.login, carla.login => org.login } }

      describe 'with one subscription' do
        before { subscription(:seven, org) }
        before { run }

        it { expect(selected).to eq 5 }
        it { expect(limit.selected.map(&:owner).map(&:login)).to eq ['svenfuchs'] * 3 + ['travis-ci'] * 2 }
        it { expect(report).to include('max jobs for user svenfuchs by plan: 7 (travis-ci)') }
        it { expect(report).to include('user svenfuchs, user carla, org travis-ci: total: 6, running: 2, queueable: 5') }
        it { expect(limit.waiting_by_owner).to eq 1 }
      end

      describe 'with multiple subscriptions' do
        before { subscription(:one, owner) }
        before { subscription(:seven, org) }
        before { run }

        it { expect(selected).to eq 6 }
        it { expect(limit.selected.map(&:owner).map(&:login)).to eq ['svenfuchs'] * 3 + ['travis-ci'] * 3 }
        it { expect(report).to include('max jobs for user svenfuchs by plan: 9 (svenfuchs, travis-ci)') }
        it { expect(report).to include('user svenfuchs, user carla, org travis-ci: total: 6, running: 2, queueable: 6') }
      end
    end
  end

  describe 'stages' do
    describe 'with private jobs only' do
      let(:one) { FactoryGirl.create(:stage, number: 1) }
      let(:two) { FactoryGirl.create(:stage, number: 2) }
      let(:three) { FactoryGirl.create(:stage, number: 3) }

      before { create_jobs(1, owner: owner, state: :created, private: true, stage: one, stage_number: '1.1') }
      before { create_jobs(1, owner: owner, state: :created, private: true, stage: one, stage_number: '1.2') }
      before { create_jobs(1, owner: owner, state: :created, private: true, stage: two, stage_number: '2.1') }
      before { create_jobs(1, owner: owner, state: :created, private: true, stage: three, stage_number: '10.1') }
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

    describe 'with public jobs only' do
      let(:one) { FactoryGirl.create(:stage, number: 1) }
      let(:two) { FactoryGirl.create(:stage, number: 2) }
      let(:three) { FactoryGirl.create(:stage, number: 3) }

      before { create_jobs(1, owner: owner, state: :created, private: false, stage: one, stage_number: '1.1') }
      before { create_jobs(1, owner: owner, state: :created, private: false, stage: one, stage_number: '1.2') }
      before { create_jobs(1, owner: owner, state: :created, private: false, stage: two, stage_number: '2.1') }
      before { create_jobs(1, owner: owner, state: :created, private: false, stage: three, stage_number: '10.1') }
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

    describe 'for mixed public and private jobs' do
      let(:one) { FactoryGirl.create(:stage, number: 1) }
      let(:two) { FactoryGirl.create(:stage, number: 2) }
      let(:three) { FactoryGirl.create(:stage, number: 3) }

      before { create_jobs(1, owner: owner, state: :created, private: true,  stage: one, stage_number: '1.1') }
      before { create_jobs(1, owner: owner, state: :created, private: false, stage: one, stage_number: '1.2') }
      before { create_jobs(1, owner: owner, state: :created, private: true,  stage: two, stage_number: '2.1') }
      before { create_jobs(1, owner: owner, state: :created, private: false, stage: three, stage_number: '10.1') }
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
    describe 'with private jobs only' do
      env BY_QUEUE_NAME: 'builds.osx'
      env BY_QUEUE_LIMIT: 'svenfuchs=2'

      before { create_jobs(9, private: true, queue: 'builds.osx') }
      before { create_jobs(1, private: true, queue: 'builds.docker') }
      before { config.limit.default = 99 }
      before { run }

      it { expect(selected).to eq 3 }
      it { expect(report).to include('max jobs for user svenfuchs by queue builds.osx: 2') }
      it { expect(report).to include('user svenfuchs: total: 10, running: 0, queueable: 3') }
    end

    describe 'with public jobs only' do
      env BY_QUEUE_NAME: 'builds.osx'
      env BY_QUEUE_LIMIT: 'svenfuchs=2'

      before { create_jobs(9, private: false, queue: 'builds.osx') }
      before { create_jobs(1, private: false, queue: 'builds.docker') }
      before { config.limit.default = 99 }
      before { run }

      it { expect(selected).to eq 3 }
      it { expect(report).to include('max jobs for user svenfuchs by queue builds.osx: 2') }
      it { expect(report).to include('user svenfuchs: total: 10, running: 0, queueable: 3') }
    end

    describe 'for mixed public and private jobs' do
      env BY_QUEUE_NAME: 'builds.osx'
      env BY_QUEUE_LIMIT: 'svenfuchs=2'

      before { create_jobs(4, private: true, queue: 'builds.osx') }
      before { create_jobs(1, private: true, queue: 'builds.docker') }
      before { create_jobs(4, private: false, queue: 'builds.osx') }
      before { create_jobs(1, private: false, queue: 'builds.docker') }
      before { config.limit.default = 99 }
      before { run }

      it { expect(selected).to eq 4 }
      it { expect(report).to include('max jobs for user svenfuchs by queue builds.osx: 2') }
      it { expect(report).to include('user svenfuchs: total: 10, running: 0, queueable: 4') }
    end
  end

  describe 'with a by_queue limit of 2 for the owner and a repo limit of 3 on another repo' do
    describe 'with private jobs only' do
      env BY_QUEUE_NAME: 'builds.osx'
      env BY_QUEUE_LIMIT: 'svenfuchs=2'
      env BY_QUEUE_DEFAULT: 2

      let(:other) { FactoryGirl.create(:repo, github_id: 2) }
      before { create_jobs(9, private: true, repository: repo, queue: 'builds.osx') }
      before { create_jobs(5, private: true, repository: other, queue: 'builds.docker') }
      before { config.limit.default = 99 }
      before { other.settings.update_attributes!(maximum_number_of_builds: 3) }
      before { run }

      it { expect(selected).to eq 5 }
      it { expect(report).to include('max jobs for user svenfuchs by queue builds.osx: 2') }
      it { expect(report).to include('user svenfuchs: total: 14, running: 0, queueable: 5') }
    end

    describe 'with public jobs only' do
      env BY_QUEUE_NAME: 'builds.osx'
      env BY_QUEUE_LIMIT: 'svenfuchs=2'
      env BY_QUEUE_DEFAULT: 2

      let(:other) { FactoryGirl.create(:repo, github_id: 2) }
      before { create_jobs(9, private: false, repository: repo, queue: 'builds.osx') }
      before { create_jobs(5, private: false, repository: other, queue: 'builds.docker') }
      before { config.limit.default = 99 }
      before { other.settings.update_attributes!(maximum_number_of_builds: 3) }
      before { run }

      it { expect(selected).to eq 5 }
      it { expect(report).to include('max jobs for user svenfuchs by queue builds.osx: 2') }
      it { expect(report).to include('user svenfuchs: total: 14, running: 0, queueable: 5') }
    end

    describe 'for mixed public and private jobs' do
      env BY_QUEUE_NAME: 'builds.osx'
      env BY_QUEUE_LIMIT: 'svenfuchs=2'
      env BY_QUEUE_DEFAULT: 2

      let(:other) { FactoryGirl.create(:repo, github_id: 2) }
      before { create_jobs(4, private: true,  repository: repo, queue: 'builds.osx') }
      before { create_jobs(2, private: true,  repository: other, queue: 'builds.docker') }
      before { create_jobs(4, private: false, repository: repo, queue: 'builds.osx') }
      before { create_jobs(2, private: false, repository: other, queue: 'builds.docker') }
      before { config.limit.default = 99 }
      before { other.settings.update_attributes!(maximum_number_of_builds: 3) }
      before { run }

      it { expect(selected).to eq 5 }
      it { expect(report).to include('max jobs for user svenfuchs by queue builds.osx: 2') }
      it { expect(report).to include('user svenfuchs: total: 12, running: 0, queueable: 5') }
    end
  end

  describe 'with a by_queue limit for the owner and jobs created for a different queue' do
    env BY_QUEUE_NAME: 'builds.osx'
    env BY_QUEUE_LIMIT: 'svenfuchs=2'
    before { config.limit.default = 3 }

    describe 'with private jobs only' do
      before { create_jobs(4, queue: 'builds.docker', private: true) }
      before { create_jobs(1, queue: 'builds.osx', private: true) }
      before { run }

      it { expect(selected).to eq 3 }
      it { expect(report).to include('max jobs for user svenfuchs by default: 3') }
      it { expect(report).to include('user svenfuchs: total: 5, running: 0, queueable: 3') }
      it { expect(limit.waiting_by_owner).to eq 2 }
    end

    describe 'with public jobs only' do
      before { create_jobs(4, queue: 'builds.docker', private: true) }
      before { create_jobs(1, queue: 'builds.osx', private: true) }
      before { run }

      it { expect(selected).to eq 3 }
      it { expect(report).to include('max jobs for user svenfuchs by default: 3') }
      it { expect(report).to include('user svenfuchs: total: 5, running: 0, queueable: 3') }
      it { expect(limit.waiting_by_owner).to eq 2 }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(2, queue: 'builds.docker', private: true) }
      before { create_jobs(1, queue: 'builds.osx', private: true) }
      before { create_jobs(2, queue: 'builds.docker', private: false) }
      before { create_jobs(1, queue: 'builds.osx', private: false) }
      before { run }

      # TODO this is totally off and probably breaking expectations once in use
      it { expect(selected).to eq 6 }
      it { expect(report).to include('max jobs for user svenfuchs by default: 6') }
      it { expect(report).to include('user svenfuchs: total: 6, running: 0, queueable: 6') }
      it { expect(limit.waiting_by_owner).to eq 0 }
    end
  end
end
