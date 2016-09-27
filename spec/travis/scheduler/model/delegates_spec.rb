describe Travis::Scheduler::Model::Delegates do
  let(:config)    { { limit: { delegate: { sven: 'travis', carla: 'travis' } } } }
  let(:delegates) { described_class.new(login, config) }

  subject { delegates.logins }

  describe 'given a delegator login' do
    let(:login) { 'sven' }
    it { expect(subject).to eq ['sven', 'travis', 'carla'] }
  end

  describe 'given a delegatee login' do
    let(:login) { 'travis' }
    it { expect(subject).to eq ['travis', 'sven', 'carla'] }
  end
end
