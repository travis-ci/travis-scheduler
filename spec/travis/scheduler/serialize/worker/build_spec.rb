describe Travis::Scheduler::Serialize::Worker::Build do
  let(:build) { Build.new(event_type: event_type) }
  subject { described_class.new(build) }

  describe 'pull_request?' do
    describe 'with event_type :push' do
      let(:event_type) { 'push' }
      it { expect(subject.pull_request?).to be false }
    end

    describe 'with event_type :pull_request' do
      let(:event_type) { 'pull_request' }
      it { expect(subject.pull_request?).to be true }
    end
  end
end
