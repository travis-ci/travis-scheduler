describe Travis::Scheduler::Serialize::Worker::Job do
  let(:request) { Request.new }
  let(:build)   { Build.new(request: request) }
  let(:repository) { Repository.new }
  let(:job)     { Job.new(source: build, config: config, repository: repository) }
  let(:config)  { {} }
  subject       { described_class.new(job) }

  describe 'env_vars' do
    xit
  end

  describe 'pull_request?' do
    describe 'with event_type :push' do
      before { build.event_type = 'push' }
      it { expect(subject.pull_request?).to be false }
    end

    describe 'with event_type :pull_request' do
      before { build.event_type = 'pull_request' }
      it { expect(subject.pull_request?).to be true }
    end
  end

  describe '#secure_env?' do
    describe 'with a push event' do
      before { build.event_type = 'push' }
      it { expect(subject.secure_env?).to eq(true) }
    end

    describe 'with a pull_request event' do
      before { build.event_type = 'pull_request' }

      describe 'from the same repository' do
        before { request.stubs(:same_repo_pull_request?).returns(true) }
        it { expect(subject.secure_env?).to eq(true) }
      end

      describe 'from a different repository' do
        before { request.stubs(:same_repo_pull_request?).returns(false) }
        it { expect(subject.secure_env?).to eq(false) }
      end
    end
  end

  describe '#secure_env_vars_removed?' do
    describe 'with a push event' do
      before { build.event_type = 'push' }
      it { expect(subject.secure_env_vars_removed?).to eq(false) }
    end

    describe 'with a pull_request event' do
      before { build.event_type = 'pull_request' }

      describe 'from the same repository' do
        before { request.stubs(:same_repo_pull_request?).returns(true) }
        it { expect(subject.secure_env_vars_removed?).to eq(false) }
      end

      describe 'from a different repository' do
        before { request.stubs(:same_repo_pull_request?).returns(false) }

        context "when .travis.yml defines a secure var" do
          let(:config) { { env: { secure: "secret" } } }
          it { expect(subject.secure_env_vars_removed?).to eq(true) }
        end

        context "when repository settings define a secure var" do
          before { repository.settings.stubs(:has_secure_vars?).returns(true) }
          it { expect(subject.secure_env_vars_removed?).to eq(true) }
        end
      end

    end
  end
end
