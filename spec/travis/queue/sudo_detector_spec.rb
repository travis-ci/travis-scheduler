describe Travis::Queue::SudoDetector do
  let(:sudo) { described_class.new(config) }

  describe 'sudo_detected?' do
    configs = [
      [{ script: 'sudo echo' }, true],
      [{ bogus: 'sudo echo' }, false],
      [{ before_install: ['# no sudo', 'ping -c 1 google.com'] }, true],
      [{ before_install: ['docker run busybox echo whatever'] }, true],
      [{ before_script: ['echo ; echo ; echo ; sudo echo ; echo'] }, true],
      [{ install: '# no sudo needed here' }, false],
      [{ install: true }, false],
    ]

    configs.each do |config, result|
      describe "with #{config}" do
        let(:config) { config }
        it { expect(sudo.detect?).to eq result }
      end
    end
  end
end
