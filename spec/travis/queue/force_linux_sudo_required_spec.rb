describe Travis::Queue::ForceLinuxSudoRequired do
  let(:config) { {} }
  let(:owner) { FactoryGirl.build(:user, login: 'cabbagen') }
  let(:repo) { FactoryGirl.build(:repo, owner: owner) }

  subject { described_class.new(repo, owner) }

  before do
    Travis::Scheduler.logger.stubs(:info)
  end

  context 'when enabled for all' do
    it 'applies' do
      Travis::Features
        .stubs(:enabled_for_all?)
        .with(:force_linux_sudo_required)
        .returns(true)
      expect(subject.apply?).to be true
    end
  end

  context 'when repo is active' do
    it 'applies' do
      Travis::Features
        .stubs(:active?)
        .with(:force_linux_sudo_required, repo)
        .returns(true)
      expect(subject.apply?).to be true
    end
  end

  context 'when owner is active' do
    it 'applies' do
      Travis::Features
        .stubs(:owner_active?)
        .with(:force_linux_sudo_required, owner)
        .returns(true)
      expect(subject.apply?).to be true
    end
  end

  context 'when first job' do
    it 'applies' do
      subject.stubs(:first_job?).returns(true)
      expect(subject.apply?).to be true
    end
  end

  context 'when random' do
    it 'applies' do
      subject.stubs(:first_job?).returns(false)
      subject.stubs(:rollout_force_linux_sudo_required_percentage).returns(1)
      expect(subject.apply?).to be true
    end
  end
end
