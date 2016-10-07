describe Travis::Scheduler::Service::Event do
  let!(:org)    { FactoryGirl.create(:org, login: 'travis-ci') }
  let(:repo)    { FactoryGirl.create(:repo) }
  let(:owner)   { FactoryGirl.create(:user) }
  let(:build)   { FactoryGirl.create(:build, repository: repo, owner: owner, jobs: [job]) }
  let(:job)     { FactoryGirl.create(:job, state: :created) }
  let(:config)  { Travis::Scheduler.context.config }
  let(:data)    { { id: build.id, jid: '1234' } }
  let(:event)   { 'build:created' }
  let(:service) { described_class.new(Travis::Scheduler.context, event, data) }

  before { config.limit.delegate = { owner.login => org.login } }
  before { config.limit.default = 1 }
  before { service.run }

  it { expect(Job.first.state).to eq 'queued' }

  it { expect(log).to include "Evaluating jobs for owner group: user svenfuchs, org travis-ci" }
  it { expect(log).to include "enqueueing job #{Job.first.id} (svenfuchs/gem-release)" }
  it { expect(log).to include "max jobs for user svenfuchs by default: 1" }
  it { expect(log).to include "user svenfuchs, org travis-ci: total: 1, running: 0, queueable: 1" }
end
