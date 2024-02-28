# frozen_string_literal: true

describe Travis::Owners::Config do
  subject { delegates.send(:logins).sort }

  let(:config)    { { limit: { delegate: { sven: 'travis', carla: 'travis' } } } }
  let(:owner)     { FactoryBot.create(:user, login: 'sven') }
  let(:delegates) { described_class.new(owner, config) }

  describe 'given a delegator login' do
    let(:login) { 'sven' }

    it { expect(subject).to eq %w[carla sven travis] }
  end

  describe 'given a delegatee login' do
    let(:login) { 'travis' }

    it { expect(subject).to eq %w[carla sven travis] }
  end
end
