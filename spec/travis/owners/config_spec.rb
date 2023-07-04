describe Travis::Owners::Config do
  let(:config)    { { limit: { delegate: { sven: 'travis', carla: 'travis' } } } }
  let(:owner)     { FactoryBot.create(:user, login: 'sven') }
  let(:delegates) { described_class.new(owner, config) }

  subject { delegates.send(:logins).sort }

  describe 'given a delegator login' do
    let(:login) { 'sven' }
    it { expect(subject).to eq ['carla', 'sven', 'travis'] }
  end

  describe 'given a delegatee login' do
    let(:login) { 'travis' }
    it { expect(subject).to eq ['carla', 'sven', 'travis'] }
  end
end
