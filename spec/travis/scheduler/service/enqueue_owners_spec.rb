describe Travis::Scheduler::Service::EnqueueOwners do
  let!(:org)    { FactoryGirl.create(:org, login: 'travis-ci') }
  let(:repo)    { FactoryGirl.create(:repo, owner: owner) }
  let(:owner)   { FactoryGirl.create(:user) }
  let(:commit)  { FactoryGirl.create(:commit) }
  let(:config)  { Travis::Scheduler.context.config }
  let(:data)    { { owner_type: 'User', owner_id: owner.id } }
  let(:service) { described_class.new(Travis::Scheduler.context, data, jid: '1234') }

  before { 1.upto(2) { FactoryGirl.create(:job, commit: commit, repository: repo, owner: owner, state: :created, queue: 'builds.gce') } }
  before { config.limit.delegate = { owner.login => org.login } }
  before { config.limit.default = 1 }
  before { service.run }

  it { expect(Job.order(:id).pluck(:state)).to eq %w[queued created] }

  it { expect(log).to include "Evaluating jobs for owner group: svenfuchs, travis-ci" }
  it { expect(log).to include "enqueueing job #{Job.first.id} (svenfuchs/gem-release)" }
  it { expect(log).to include "max jobs for svenfuchs by default: 1" }
  it { expect(log).to include "svenfuchs, travis-ci: total: 2, running: 0, queueable: 1" }
end
