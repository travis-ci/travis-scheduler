# frozen_string_literal: true

describe Travis::Scheduler::Service::Event do
  let!(:org)    { FactoryBot.create(:org, login: 'travis-ci') }
  let(:repo)    { FactoryBot.create(:repo) }
  let(:owner)   { FactoryBot.create(:user) }
  let(:build)   { FactoryBot.create(:build, repository: repo, owner:, jobs: [job]) }
  let(:job_stage)   { FactoryBot.create(:stage) }
  let(:job)     { FactoryBot.create(:job, private: true, state: :created, config: config.to_h, stage_id: job_stage.id) }
  let(:config)  { Travis::Scheduler.context.config }
  let(:data)    { { id: build.id, jid: '1234' } }
  let(:event)   { 'build:created' }
  let(:service) { described_class.new(Travis::Scheduler.context, event, data) }
  let(:authorize_build_url) { "http://localhost:9292/users/#{owner.id}/plan" }

  context do
    before do
      Travis::JobBoard.stubs(:post)
      config.limit.delegate = { owner.login => org.login }
      config.limit.by_owner = { org.login => 1 }
      stub_request(:get, authorize_build_url).to_return(
        body: MultiJson.dump(plan_name: 'two_concurrent_plan', hybrid: true, free: false, status: 'subscribed',
                             metered: false)
      )
      service.run
    end

    it { expect(Job.first.state).to eq 'queued' }

    it { expect(log).to include 'Evaluating jobs for owner group: user svenfuchs, org travis-ci' }
    it { expect(log).to include "enqueueing job #{Job.first.id} (svenfuchs/gem-release)" }
    it { expect(log).to include 'user svenfuchs, org travis-ci capacities: public max=5, config max=1' }

    it {
      expect(log).to include 'user svenfuchs, org travis-ci: queueable=1 running=0 selected=1 total_waiting=0 waiting_for_concurrency=0'
    }
  end

  describe 'owner group already locked' do
    before do
      Travis::Lock.stubs(:exclusive).raises(Travis::Lock::Redis::LockError.new('scheduler.owners-svenfuchs'))
      service.run
    end

    it {
      expect(log).to include "I 1234 Owner group scheduler.owners-svenfuchs is locked and already being evaluated. Dropping event build:created for build=#{build.id}"
    }
  end
end
