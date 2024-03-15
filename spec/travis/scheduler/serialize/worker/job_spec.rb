# frozen_string_literal: true

describe Travis::Scheduler::Serialize::Worker::Job do
  subject       { described_class.new(job) }

  let(:request) { Request.new }
  let(:build)   { Build.new(request:) }
  let(:repo)    { FactoryBot.create(:repository) }
  let(:job)     { Job.new(source: build, config:, repository: repo) }
  let(:config)  { {} }

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

      describe 'with secure env allowed in the PR' do
        before { repo.settings.stubs(:share_encrypted_env_with_forks).returns(true) }
        it { expect(subject.secure_env?).to eq(true) }
      end

      describe 'with secure env forbidden in the PR' do
        before { repo.settings.stubs(:share_encrypted_env_with_forks).returns(false) }
        it { expect(subject.secure_env?).to eq(false) }
      end
    end
  end

  describe '#secure_env_removed?' do
    describe 'with a push event' do
      before { build.event_type = 'push' }

      it { expect(subject.secure_env_removed?).to eq(false) }
    end

    describe 'with a pull_request event' do
      before { build.event_type = 'pull_request' }

      describe 'from the same repository' do
        before { request.stubs(:same_repo_pull_request?).returns(true) }

        it { expect(subject.secure_env_removed?).to eq(false) }
      end

      describe 'from a different repository' do
        before { request.stubs(:same_repo_pull_request?).returns(false) }

        context 'when .travis.yml defines a secure var' do
          let(:config) { { env: { secure: 'secret' } } }

          it { expect(subject.secure_env_removed?).to eq(false) }
        end

        context 'when repository settings define a secure var' do
          before { repo.settings.stubs(:has_secure_vars?).returns(true) }

          it { expect(subject.secure_env_removed?).to eq(true) }
        end
      end
    end
  end

  describe 'secrets' do
    let(:config) do
      {
        env: {
          global: [
            { secure: Base64.encode64(repo.key.encrypt('one')) },
            { secure: Base64.encode64(repo.key.encrypt('two')) },
            'FOO=foo'
          ]
        },
        deploy: [
          {
            provider: 's3',
            secret_access_token: {
              secure: Base64.encode64(repo.key.encrypt('three'))
            }
          }
        ]
      }
    end

    it { expect(subject.secrets).to eq %w[one two three] }
  end

  describe 'decrypted config' do
    context 'when in a pull request' do
      let(:config) do
        {
          env: [
            { BAR: 'bar' },
            { secure: Base64.encode64(repo.key.encrypt('MAIN=1')) }
          ]
        }
      end
      let(:request) { Request.new(pull_request:) }

      before do
        build.event_type = 'pull_request'
      end

      context 'when head repo is present' do
        let(:head_repo) { FactoryBot.create(:repository, github_id: 549_744) }
        let(:head_repo_key) { OpenSSL::PKey::RSA.generate(4096) }
        let(:pull_request) { PullRequest.new(base_repo_slug: 'travis-ci/travis-yml', head_repo_slug: "#{head_repo.owner_name}/#{head_repo.name}") }

        it do
          expect(subject.decrypted_config[:env]).to eq(['BAR=bar', 'SECURE MAIN=1'])
        end
      end

      context 'when head repo is not found' do
        let(:pull_request) { PullRequest.new(base_repo_slug: 'travis-ci/travis-yml', head_repo_slug: 'mytest/letssee') }

        it 'returns garbage' do
          expect(subject.decrypted_config[:env]).to eq(['BAR=bar', 'SECURE [unable to decrypt]'])
        end
      end
    end

    context 'when in a push' do
      let(:config) do
        {
          env: [
            { BAR: 'bar' },
            { secure: Base64.encode64(repo.key.encrypt('MAIN=1')) }
          ]
        }
      end

      before do
        build.event_type = 'push'
      end

      it do
        expect(subject.decrypted_config[:env]).to eq(['BAR=bar', 'SECURE MAIN=1'])
      end
    end
  end

  describe 'decrypted config' do
    context 'when in a pull request' do
      let(:config) do
        {
          env: [
            { :BAR => 'bar' },
            { secure: Base64.encode64(repo.key.encrypt('MAIN=1')) },
          ]
        }
      end
      let(:request) { Request.new(pull_request: pull_request) }

      before do
        build.event_type = 'pull_request'
      end

      context 'when head repo is present' do
        let(:head_repo) { FactoryGirl.create(:repository, github_id: 549744) }
        let(:head_repo_key) { OpenSSL::PKey::RSA.generate(4096) }
        let(:pull_request) { PullRequest.new(base_repo_slug: 'travis-ci/travis-yml', head_repo_slug: "#{head_repo.owner_name}/#{head_repo.name}") }

        it do
          expect(subject.decrypted_config[:env]).to eq(['BAR=bar', 'SECURE MAIN=1'])
        end
      end

      context 'when head repo is not found' do
        let(:pull_request) { PullRequest.new(base_repo_slug: 'travis-ci/travis-yml', head_repo_slug: 'mytest/letssee') }

        it 'returns garbage' do
          expect(subject.decrypted_config[:env]).to eq(['BAR=bar', 'SECURE [unable to decrypt]'])
        end
      end
    end

    context 'when in a push' do
      let(:config) do
        {
          env: [
            { :BAR => 'bar' },
            { secure: Base64.encode64(repo.key.encrypt('MAIN=1')) },
          ]
        }
      end

      before do
        build.event_type = 'push'
      end

      it do
        expect(subject.decrypted_config[:env]).to eq(['BAR=bar', 'SECURE MAIN=1'])
      end
    end
  end
end
