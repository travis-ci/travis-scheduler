describe Travis::Queue::ForcePreciseSudoRequired do
  let(:dist) { 'precise' }
  let(:config) { { dist: dist } }
  let(:created_at) { Time.now }
  let(:owner) { FactoryGirl.build(:user, login: 'cabbagen') }
  let(:enabled_for_all?) { false }
  let(:active?) { false }

  let(:repo) do
    FactoryGirl.build(
      :repo, owner: owner, owner_name: owner.login,
      name: 'noodles', created_at: created_at
    )
  end

  let(:job) { FactoryGirl.build(:job, config: config, repository: repo) }

  subject { described_class.new(repo, dist) }

  before do
    Travis::Features
      .stubs(:enabled_for_all?)
      .with(:precise_sudo_required)
      .returns(enabled_for_all?)
    Travis::Features
      .stubs(:active?)
      .with(:precise_sudo_required, repo)
      .returns(active?)
    Travis::Scheduler.logger.stubs(:info)
  end

  context 'with dist trusty' do
    let(:dist) { 'trusty' }

    it 'does not apply' do
      expect(subject.apply?).to be false
    end
  end

  context 'when enabled for all' do
    let(:enabled_for_all?) { true }

    it 'applies' do
      expect(subject.apply?).to be true
    end
  end

  context 'when repo is active' do
    let(:active?) { true }

    it 'applies' do
      expect(subject.apply?).to be true
    end
  end

  context 'when first job' do
    before do
      subject.stubs(:first_job_id).returns(nil)
    end

    it 'activates the repository' do
      Travis::Features
        .expects(:activate_repository)
        .with(:precise_sudo_required, repo)
      subject.apply?
    end
  end

  context 'when randomly selected' do
    before do
      subject.stubs(:first_job_id).returns(4)
      subject.stubs(:rand).returns(-1)
    end

    it 'activates the repository' do
      Travis::Features
        .expects(:activate_repository)
        .with(:precise_sudo_required, repo)
      subject.apply?
    end
  end
end
