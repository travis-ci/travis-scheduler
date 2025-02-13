# frozen_string_literal: true

describe Travis::Scheduler::Serialize::Worker::Job, 'env_vars' do
  subject(:job_instance)       { described_class.new(job) }

  let(:request) { Request.new }
  let(:build)   { Build.new(request:) }
  let(:repo)    { FactoryBot.create(:repository) }
  let(:job)     { Job.new(source: build, config:, repository: repo) }
  let(:config)  { {} }

  let(:account_env_vars) do
    [
      {name: 'ACCOUNT_SECURE_VAR', value: 'secure_value', public: false, branch: nil},
      {name: 'PUBLIC_VAR', value: 'account_public_value', public: true, branch: nil}
    ]
  end

  let(:env_vars) do
    Repository::Settings::EnvVars.new(
      Repository::Settings::EnvVar.new(name: 'SECURE_VAR', value: 'secure_value', public: false, branch: nil),
      Repository::Settings::EnvVar.new(name: 'PUBLIC_VAR', value: 'repo_public_value', public: true, branch: 'main')
    )
  end



  describe 'env_vars' do
    before do
      repo.settings.stubs(:env_vars).returns(env_vars)
      repo.settings.stubs(:share_encrypted_env_with_forks).returns(true)
      request.stubs(:same_repo_pull_request?).returns(true)
      repo.stubs(:fork?).returns(false)
      build.event_type = 'push'
      job_instance.stubs(:account_env_vars).returns(account_env_vars)
    end

    context 'when is pull request and is not for same repo' do
      before do
        build.event_type = 'pull_request'
        request.stubs(:same_repo_pull_request?).returns(false)
      end

      it 'should return only repo env vars' do
        expect(job_instance.env_vars).to eq(
                                           [
                                             { name: 'SECURE_VAR', value: 'secure_value', public: false, branch: nil },
                                             { name: 'PUBLIC_VAR', value: 'repo_public_value', public: true, branch: 'main' }
                                           ]
                                         )
      end
    end

    # context 'when it is not pull_request but its forked repository' do
    #   before do
    #     repo.stubs(:fork?).returns(true)
    #   end
    #
    #   it 'should return only repo env vars' do
    #     expect(job_instance.env_vars).to eq(
    #                                        [
    #                                          { name: 'SECURE_VAR', value: 'secure_value', public: false, branch: nil },
    #                                          { name: 'PUBLIC_VAR', value: 'repo_public_value', public: true, branch: 'main' }
    #                                        ]
    #                                      )
    #   end
    # end

    context 'when environment is not secure then non-public env vars should not apply' do
      before do
        build.event_type = 'pull_request'
        request.stubs(:same_repo_pull_request?).returns(false)
        repo.settings.stubs(:share_encrypted_env_with_forks).returns(false)
      end

      it 'should return only public repo env vars' do
        expect(job_instance.env_vars).to eq(
                                           [
                                             { name: 'PUBLIC_VAR', value: 'repo_public_value', public: true, branch: 'main' }
                                           ]
                                         )
      end
    end

    context 'when it is not pull request then account env vars should apply as well' do
      before do
        build.event_type = 'push'

      end

      it 'should return all env vars, overriding account env vars if the name is the same' do
        expect(job_instance.env_vars).to eq(
                                           [
                                             { name: 'ACCOUNT_SECURE_VAR', value: 'secure_value', public: false, branch: nil },
                                             { name: 'PUBLIC_VAR', value: 'repo_public_value', public: true, branch: 'main' },
                                             { name: 'SECURE_VAR', value: 'secure_value', public: false, branch: nil }
                                           ]
                                         )
      end
    end
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
        let(:head_repo) { FactoryBot.create(:repository, github_id: 549744) }
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

  describe '#restarted_by_login' do
    let(:user) { User.create(login: 'test_user') }
    let(:job) { Job.new(restarted_by: user.id) }

    it 'returns the login of the user who restarted the job' do
      expect(subject.restarted_by_login).to eq('test_user')
    end
  end
end
