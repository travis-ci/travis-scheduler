describe Travis::Scheduler::Config do
  let(:config) { Travis::Scheduler::Config.load }

  subject { config.log_level }

  describe 'given no env var' do
    it { should eq :info }
  end

  describe 'given TRAVIS_LOG_LEVEL=debug' do
    env TRAVIS_LOG_LEVEL: :debug

    it { should eq :debug }
  end
end
