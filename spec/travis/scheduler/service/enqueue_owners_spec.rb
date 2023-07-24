describe Travis::Scheduler::Service::EnqueueOwners do
  let!(:org)    { FactoryBot.create(:org, login: 'travis-ci') }
  let(:repo)    { FactoryBot.create(:repo, owner:) }
  let(:owner)   { FactoryBot.create(:user) }
  let(:commit)  { FactoryBot.create(:commit) }
  let(:job)     { Job.first }
  let(:config)  { Travis::Scheduler.context.config }
  let(:data)    { { owner_type: 'User', owner_id: owner.id, jid: '1234' } }
  let(:service) { described_class.new(Travis::Scheduler.context, data) }
  let(:authorize_build_url) { "http://localhost:9292/users/#{owner.id}/plan" }

  before { Travis::JobBoard.stubs(:post) }

  before do
    1.upto(2) do
      FactoryBot.create(:job, commit:, repository: repo, owner:, private: true, state: :created, queue: 'builds.gce',
                              config: {})
    end
  end
  before { config.limit.delegate = { owner.login => org.login } }
  before { config.limit.by_owner = { org.login => 1 } }
  before do
    stub_request(:get, authorize_build_url).to_return(
      body: MultiJson.dump(plan_name: 'two_concurrent_plan', hybrid: true, free: false, status: 'subscribed',
                           metered: false)
    )
  end
  before { service.run }

  it { expect(Job.order(:id).map(&:state)).to eq %w[queued created] }
  it { expect(Job.order(:id).map { |job| !!job.queueable }).to eq [false, true] }

  it { expect(log).to include 'I 1234 Locking scheduler.owners-svenfuchs:travis-ci with: redis, ttl: 150s' }
  it { expect(log).to include 'I 1234 Evaluating jobs for owner group: user svenfuchs, org travis-ci' }
  it { expect(log).to include 'I 1234 user svenfuchs, org travis-ci config capacity: running=0 max=1 selected=1' }
  it { expect(log).to include 'I 1234 repo svenfuchs/gem-release: queueable=2 running=0 selected=1 waiting=1' }
  it {
    expect(log).to include 'I 1234 user svenfuchs, org travis-ci: queueable=2 running=0 selected=1 total_waiting=1 waiting_for_concurrency=1'
  }
  it { expect(log).to include "I 1234 enqueueing job #{job.id} (svenfuchs/gem-release)" }
  it { expect(log).to include "I 1234 Publishing worker payload for job=#{job.id} queue=builds.gce" }

  describe 'with invalid owner data' do
    let(:data) { { owner_type: nil, owner_id: 0 } }
    before { service.run }
    it { expect(log).to include 'E Invalid owner data: {:owner_type=>nil, :owner_id=>0}' }
  end
end
