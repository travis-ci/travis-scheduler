
require 'travis/scheduler/serialize/worker'

describe Travis::Scheduler::Serialize::Worker do
  def encrypted(value)
    Travis::Settings::EncryptedColumn.new(use_prefix: false).dump(value)
  end

  let(:features)  { Travis::Features }
  let(:job)       { FactoryBot.create(:job, repository: repo, source: build, commit: commit, state: :queued, config: { rvm: '1.8.7', gemfile: 'Gemfile.rails', name: 'jobname' }, queued_at: Time.parse('2016-01-01T10:30:00Z'), allow_failure: allow_failure) }
  let(:request)   { FactoryBot.create(:request, repository: repo, event_type: event) }
  let(:build)     { FactoryBot.create(:build, request: request, event_type: event, pull_request_number: pr_number) }
  let(:commit)    { FactoryBot.create(:commit, request: request, ref: ref) }
  let(:repo)      { FactoryBot.create(:repo, default_branch: 'branch') }
  let(:owner)     { repo.owner }
  let(:data)      { described_class.new(job, config).data }
  let(:config)    { { cache_settings: { 'builds.gce' => s3 }, workspace: { 'builds.gce' => s3 }, github: { source_host: 'github.com', api_url: 'https://api.github.com' }, vm_configs: {} } }
  let(:s3)        { { access_key_id: 'ACCESS_KEY_ID', secret_access_key: 'SECRET_ACCESS_KEY', bucket_name: 'bucket' } }
  let(:event)     { 'push' }
  let(:ref)       { 'refs/tags/v1.2.3' }
  let(:pr_number) { nil }
  let(:payload)   { {} }
  let(:allow_failure) { false }

  let(:raw_settings) do
    {
      env_vars: [
        { name: 'FOO', value: encrypted('foo'), branch: 'foo-(dev)' },
        { name: 'BAR', value: encrypted('bar'), public: true }
      ],
      timeout_hard_limit: 180,
      timeout_log_silence: 20
    }
  end
  let(:settings) { Repository::Settings.load(raw_settings) }

  before { job.repository.stubs(:settings).returns(settings) }

  describe 'for a push request' do
    it 'data' do
      expect(data).to eq(
        type: :test,
        vm_type: :default,
        vm_config: {},
        vm_size: nil,
        queue: 'builds.gce',
        config: {
          rvm: '1.8.7',
          gemfile: 'Gemfile.rails',
          name: 'jobname',
        },
        env_vars: [
          { name: 'FOO', value: 'foo', public: false, branch: 'foo-(dev)' },
          { name: 'BAR', value: 'bar', public: true, branch: nil }
        ],
        job: {
          id: job.id,
          number: '2.1',
          commit: '62aaef',
          commit_range: '0cd9ff...62aaef',
          commit_message: 'message',
          branch: 'master',
          ref: nil,
          tag: 'v1.2.3',
          pull_request: false,
          state: 'queued',
          secure_env_enabled: true,
          secure_env_removed: false,
          debug_options: {},
          queued_at: '2016-01-01T10:30:00Z',
          allow_failure: allow_failure,
          stage_name: nil,
          name: 'jobname',
        },
        host: 'https://travis-ci.com',
        source: {
          id: build.id,
          number: '2',
          event_type: 'push'
        },
        repository: {
          id: repo.id,
          github_id: 549743,
          vcs_id: '549743',
          vcs_type: 'GithubRepository',
          private: false,
          slug: 'svenfuchs/gem-release',
          source_url: 'https://github.com/svenfuchs/gem-release.git',
          source_host: 'github.com',
          api_url: 'https://api.github.com/repos/svenfuchs/gem-release',
          last_build_started_at: '2016-01-01T10:00:00Z',
          last_build_finished_at: '2016-01-01T11:00:00Z',
          last_build_number: '2',
          last_build_duration: 60,
          last_build_state: 'passed',
          default_branch: 'branch',
          description: 'description',
          server_type: 'git',
        },
        ssh_key: nil,
        timeouts: {
          hard_limit: 180 * 60, # worker handles timeouts in seconds
          log_silence: 20 * 60
        },
        cache_settings: s3,
        workspace: s3,
        prefer_https: false,
        enterprise: false,
        keep_netrc: true,
        secrets: [],
        allowed_repositories: ["549743"]
      )
    end

    context 'when prefer_https is set and the repo is private' do
      before { Travis.config.prefer_https = true }
      after  { Travis.config.prefer_https = false }
      before { repo.update!(private: true) }

      it 'sets the repo source_url to an http url' do
        expect(data[:repository][:source_url]).to eq 'https://github.com/svenfuchs/gem-release.git'
      end
    end

    context 'when the repo is managed by the github app and the repo is private' do
      let!(:installation) { FactoryBot.create(:installation, github_id: rand(1000), owner_id: repo.owner_id, owner_type: repo.owner_type) }

      describe 'on a private repo with a custom ssh key' do
        before { repo.update!(private: true, managed_by_installation_at: Time.now) }
        before { repo.settings.ssh_key = { value: 'settings key' } }

        it 'sets the repo source_url to an ssh git url' do
          expect(data[:repository][:source_url]).to eq 'git@github.com:svenfuchs/gem-release.git'
        end

        it 'includes the installation id' do
          expect(data[:repository][:installation_id]).to eq installation.github_id
        end
      end

      describe 'on a private repo' do
        before { repo.update!(private: true, managed_by_installation_at: Time.now) }

        it 'sets the repo source_url to an http url' do
          expect(data[:repository][:source_url]).to eq 'https://github.com/svenfuchs/gem-release.git'
        end

        it 'includes the installation id' do
          expect(data[:repository][:installation_id]).to eq installation.github_id
        end
      end

      describe 'on a public repo' do
        before { repo.update!(private: false, managed_by_installation_at: Time.now) }

        it 'sets the repo source_url to an http url' do
          expect(data[:repository][:source_url]).to eq 'https://github.com/svenfuchs/gem-release.git'
        end

        it 'does not include the installation id' do
          expect(data[:repository][:installation_id]).to be nil
        end
      end
    end
  end

  describe 'vm_type' do
    describe 'with the feature flag active for the repo' do
      before { features.activate_repository(:premium_vms, repo) }
      after  { features.deactivate_repository(:premium_vms, repo) }
      it { expect(data[:vm_type]).to eq(:premium) }
    end

    xdescribe 'with the feature flag active for the owner' do # TODO: it won't work with current code
      before { features.activate_owner(:premium_vms, owner) }
      after  { features.deactivate_owner(:premium_vms, owner) }
      it { expect(data[:vm_type]).to eq(:premium) }
    end
  end

  describe 'vm_config' do
    before { config[:vm_configs] = { gpu: { gpu_count: 1 } } }

    describe 'with the feature flag not enabled' do
      it { expect(data[:vm_config]).to eq({}) }
    end

    describe 'with the feature flag enabled, but no resources config given' do
      before { Travis::Features.activate_repository(:resources_gpu, repo) }
      it { expect(data[:vm_config]).to eq({}) }
    end

    describe 'with the feature flag enabled, and resources config given' do
      before { Travis::Features.activate_repository(:resources_gpu, repo) }
      before { job.config[:resources] = { gpu: true } }
      it { expect(data[:vm_config]).to eq gpu_count: 1 }
    end
  end

  describe 'with debug options' do
    let(:debug_options) { { "stage" => "before_install", "previous_state" => "failed", "created_by" => "svenfuchs", "quiet" => "false" } }
    before { job.stubs(:debug_options).returns(debug_options) }
    it { expect(data[:job][:debug_options]).to eq(debug_options) }
  end

  describe 'for a pull request' do
    let(:event)     { 'pull_request' }
    let(:ref)       { 'refs/pull/180/merge' }
    let(:pr_number) { 180 }
    let(:payload)   { { 'pull_request' => { 'head' => { 'ref' => 'head_branch', 'sha' => '62aaef', 'repo' => {'full_name' => 'travis-ci/gem-release'} } } } }
    let(:pull_request) { PullRequest.create(head_ref: 'head_branch', head_repo_slug: 'travis-ci/gem-release') }

    before { request.update(pull_request: pull_request, base_commit: '0cd9ff', head_commit: '62aaef') }

    it 'data' do
      expect(data).to eq(
        type: :test,
        vm_type: :default,
        vm_config: {},
        vm_size: nil,
        queue: 'builds.gce',
        config: {
          rvm: '1.8.7',
          gemfile: 'Gemfile.rails',
          name: 'jobname',
        },
        env_vars: [
          { name: 'BAR', value: 'bar', public: true, branch: nil }
        ],
        job: {
          id: job.id,
          number: '2.1',
          commit: '62aaef',
          commit_range: '0cd9ff...62aaef',
          commit_message: 'message',
          branch: 'master',
          ref: 'refs/pull/180/merge',
          tag: nil,
          pull_request: 180,
          state: 'queued',
          secure_env_enabled: false,
          secure_env_removed: true,
          debug_options: {},
          queued_at: '2016-01-01T10:30:00Z',
          pull_request_head_branch: 'head_branch',
          pull_request_head_sha: '62aaef',
          allow_failure: allow_failure,
          stage_name: nil,
          name: 'jobname',
          pull_request_head_slug: 'travis-ci/gem-release',
          pull_request_base_slug: nil,
          pull_request_base_ref: nil,
          pull_request_head_url: "git@github.com:travis-ci/gem-release.git",
        },
        host: 'https://travis-ci.com',
        source: {
          id: build.id,
          number: '2',
          event_type: 'pull_request'
        },
        repository: {
          id: repo.id,
          github_id: 549743,
          vcs_id: '549743',
          vcs_type: 'GithubRepository',
          private: false,
          slug: 'svenfuchs/gem-release',
          source_url: 'https://github.com/svenfuchs/gem-release.git',
          source_host: 'github.com',
          api_url: 'https://api.github.com/repos/svenfuchs/gem-release',
          last_build_started_at: '2016-01-01T10:00:00Z',
          last_build_finished_at: '2016-01-01T11:00:00Z',
          last_build_number: '2',
          last_build_duration: 60,
          last_build_state: 'passed',
          default_branch: 'branch',
          description: 'description',
          server_type: 'git',
        },
        ssh_key: nil,
        timeouts: {
          hard_limit: 180 * 60, # worker handles timeouts in seconds
          log_silence: 20 * 60
        },
        cache_settings: s3,
        workspace: s3,
        prefer_https: false,
        enterprise: false,
        keep_netrc: true,
        secrets: [],
        allowed_repositories: ["549743"]
      )
    end

    describe 'with env sharing enabled in the repo' do
      let(:raw_settings) do
        {
          env_vars: [
            { name: 'FOO', value: encrypted('foo'), branch: 'foo-(dev)' },
            { name: 'BAR', value: encrypted('bar'), public: true }
          ],
          timeout_hard_limit: 180,
          timeout_log_silence: 20,
          share_encrypted_env_with_forks: true
        }
      end
      let(:settings) { Repository::Settings.load(raw_settings) }

      it 'enables secure env variables' do
        expect(data[:job][:secure_env_enabled]).to eq(true)
        expect(data[:env_vars].size).to eql(2)
      end
    end

    describe 'with env sharing disabled in the repo' do
      it 'skips secure env variables' do
        expect(data[:job][:secure_env_enabled]).to eq(false)
        expect(data[:env_vars].size).to eql(1)
      end
    end

    describe 'ssh key' do
      context 'when in enterprise' do
        before { config[:enterprise] = true }

        context 'when in the same repo' do
          it 'returns key from the repo' do
            expect(data[:ssh_key][:value]).to eq(repo.key.private_key)
          end
        end

        context 'when in different repos' do
          let!(:head_repo) { FactoryBot.create(:repository, owner_name: 'travis-ci', name: 'gem-release', github_id: 123) }
          let(:head_repo_key) { OpenSSL::PKey::RSA.generate(4096) }
          let(:share_ssh_keys_with_forks) { true }
          let(:raw_settings) do
            {
              env_vars: [
                { name: 'FOO', value: encrypted('foo'), branch: 'foo-(dev)' },
                { name: 'BAR', value: encrypted('bar'), public: true }
              ],
              timeout_hard_limit: 180,
              timeout_log_silence: 20,
              share_ssh_keys_with_forks: share_ssh_keys_with_forks
            }
          end
          let(:settings) { Repository::Settings.load(raw_settings) }

          before do
            head_repo.key.update(private_key: head_repo_key.to_pem, public_key: head_repo_key.public_key)
            pull_request.update(head_repo_slug: 'travis-ci/gem-release', head_ref: 'master', base_repo_slug: 'svenfuchs/gem-release', base_ref: 'master')
            request.update(repository: head_repo)
            job.update(repository: head_repo)
            stub_request(:get, "http://localhost:9292/users/#{head_repo.owner_id}/plan").
              to_return(status: 200, body: JSON.dump(1 => true))
            repo.update(private: true, created_at: '2021-01-01')
          end

          it 'returns key from the base repo' do
            expect(data[:ssh_key][:value]).to eq(repo.key.private_key)
          end

          context 'when repo is not private' do
            before { repo.update(private: false) }

            it 'returns keys from the head repo' do
              expect(data[:ssh_key][:value]).to eq(head_repo.key.private_key)
            end
          end

          context 'when not sharing SSH keys with forks' do
            before { repo.update(created_at: Time.now) }

            it 'returns keys from the head repo' do
              expect(data[:ssh_key][:value]).to eq(head_repo.key.private_key)
            end
          end
        end
      end
    end
  end

  describe 'for a build with string timeouts' do
    it { expect(data[:timeouts]).to eq hard_limit: 180 * 60, log_silence: 20 * 60 }
  end

  describe 'ssh_key' do
    before { repo.key.stubs(:private_key).returns('repo key') }

    shared_examples_for 'does not include an ssh key' do
      it { expect(data[:ssh_key]).to eq nil }
    end

    shared_examples_for 'includes an ssh key' do
      describe 'from the repo settings' do
        before { repo.settings.ssh_key = { value: 'settings key' } }
        it { expect(data[:ssh_key]).to eq(source: :repository_settings, value: 'settings key', encoded: false) }
      end

      describe 'from the job' do
        before { job.config[:source_key] = 'job config source key' }
        it { expect(data[:ssh_key]).to eq(source: :travis_yaml, value: 'job config source key', encoded: true) }
      end

      describe 'from the repo' do
        it { expect(data[:ssh_key]).to eq(source: :default_repository_key, value: 'repo key', encoded: false) }
      end
    end

    describe 'outside enterprise' do
      describe 'on a public repo' do
        before { repo.update!(private: false) }
        include_examples 'does not include an ssh key'
      end

      describe 'on a private repo' do
        before { repo.update!(private: true) }
        include_examples 'includes an ssh key'
      end
    end

    describe 'on enterprise' do
      before { config[:enterprise] = true }

      describe 'on a public repo' do
        before { repo.update!(private: false) }
        include_examples 'includes an ssh key'
      end

      describe 'on a private repo' do
        before { repo.update!(private: true) }
        include_examples 'includes an ssh key'
      end
    end
  end

  describe 'keep_netrc' do
    describe 'defaults to true' do
      it { expect(data[:keep_netrc]).to be true }
    end

    describe 'preference set to true' do
      before { repo.owner.update(preferences: { keep_netrc: true }) }
      it { expect(data[:keep_netrc]).to be true }
    end

    describe 'preference set to false' do
      before { repo.owner.update(preferences: { keep_netrc: false }) }
      it { expect(data[:keep_netrc]).to be false }
    end
  end

  context 'custom_keys' do
    let!(:organization1) {FactoryBot.create(:org, login: "org1", id: 1)}
    let!(:organization2) {FactoryBot.create(:org, login: "org2", id: 2)}
    let!(:repo)      { FactoryBot.create(:repo, default_branch: 'main') }
    let!(:membership1) {FactoryBot.create(:membership, user: repo.owner, organization: organization1) }
    let!(:membership2) {FactoryBot.create(:membership, user: repo.owner, organization: organization2) }
    let!(:custom_key1) {FactoryBot.create(:custom_key, name: 'key1', owner_id: organization1.id, owner_type: 'Organization', private_key: 'abc')}
    let!(:custom_key2) {FactoryBot.create(:custom_key, name: 'key1', owner_id: organization2.id, owner_type: 'Organization', private_key: 'def')}

    describe 'when two organization have the same key name' do
      before {
        build.update(sender_id: repo.owner.id)
        job.update(config: {:keys => ['key1']})
        repo.update(owner: organization2, owner_name: 'org2')
      }

      it { expect(data[:env_vars]).to include({:name=>"TRAVIS_key1", :value=>"ZGVm", :public=>false, :branch=>nil})}
    end

    describe 'when user has no access to organization' do
      let!(:organization3) {FactoryBot.create(:org, login: "org3", id: 3)}
      let!(:custom_key3) {FactoryBot.create(:custom_key, name: 'key1', owner_id: organization3.id, owner_type: 'Organization', private_key: 'ghi')}
      let(:raw_settings) do
        {
          env_vars: nil,
          timeout_hard_limit: 180,
          timeout_log_silence: 20,
          share_ssh_keys_with_forks: false
        }
      end

      before {
        build.update(sender_id: repo.owner.id)
        job.update(config: {:keys => ['key1']})
        repo.update(owner: organization3, owner_name: 'org3')
      }

      it { expect(data[:env_vars]).to eq([])}
    end
  end
end
