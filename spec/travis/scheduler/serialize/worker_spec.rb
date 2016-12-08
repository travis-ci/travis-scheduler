require 'travis/scheduler/serialize/worker'

describe Travis::Scheduler::Serialize::Worker do
  def encrypted(value)
    Travis::Settings::EncryptedColumn.new(use_prefix: false).dump(value)
  end

  let(:features)  { Travis::Features }
  let(:job)       { FactoryGirl.create(:job, repository: repo, source: build, commit: commit, state: :queued, config: { rvm: '1.8.7', gemfile: 'Gemfile.rails' }) }
  let(:request)   { FactoryGirl.create(:request, event_type: event, payload: payload) }
  let(:build)     { FactoryGirl.create(:build, request: request, event_type: event, pull_request_number: pr_number) }
  let(:commit)    { FactoryGirl.create(:commit, request: request, ref: ref) }
  let(:repo)      { FactoryGirl.create(:repo, default_branch: 'branch') }
  let(:owner)     { repo.owner }
  let(:data)      { described_class.new(job, config).data }
  let(:config)    { { cache_settings: { 'builds.gce' => s3 }, github: { source_host: 'github.com', api_url: 'https://api.github.com' } } }
  let(:s3)        { { access_key_id: 'ACCESS_KEY_ID', secret_access_key: 'SECRET_ACCESS_KEY', bucket_name: 'bucket' } }
  let(:event)     { 'push' }
  let(:ref)       { 'refs/tags/v1.2.3' }
  let(:pr_number) { nil }
  let(:payload)   { {} }

  let(:settings) do
    Repository::Settings.load({
      env_vars: [
        { name: 'FOO', value: encrypted('foo') },
        { name: 'BAR', value: encrypted('bar'), public: true }
      ],
      timeout_hard_limit: 180,
      timeout_log_silence: 20
    })
  end

  before { job.repository.stubs(:settings).returns(settings) }

  describe 'for a push request' do
    it 'data' do
      expect(data).to eq(
        type: :test,
        vm_type: :default,
        queue: 'builds.gce',
        config: {
          rvm: '1.8.7',
          gemfile: 'Gemfile.rails'
        },
        env_vars: [
          { name: 'FOO', value: 'foo', public: false },
          { name: 'BAR', value: 'bar', public: true }
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
          debug_options: {},
        },
        source: {
          id: build.id,
          number: '2',
          event_type: 'push'
        },
        repository: {
          id: repo.id,
          github_id: 549743,
          slug: 'svenfuchs/gem-release',
          source_url: 'https://github.com/svenfuchs/gem-release.git',
          api_url: 'https://api.github.com/repos/svenfuchs/gem-release',
          last_build_id: 1,
          last_build_started_at: '2016-01-01T10:00:00Z',
          last_build_finished_at: '2016-01-01T11:00:00Z',
          last_build_number: '2',
          last_build_duration: 60,
          last_build_state: 'passed',
          default_branch: 'branch',
          description: 'description',
        },
        ssh_key: nil,
        timeouts: {
          hard_limit: 180 * 60, # worker handles timeouts in seconds
          log_silence: 20 * 60
        },
        cache_settings: s3,
        oauth_token: nil
      )
    end
  end

  describe 'vm_type' do
    describe 'with the feature flag active for the repo' do
      before { features.activate_repository(:premium_vms, repo) }
      after  { features.deactivate_repository(:premium_vms, repo) }
      it { expect(data[:vm_type]).to eq(:premium) }
    end

    describe 'with the feature flag active for the owner' do
      before { features.activate_owner(:premium_vms, owner) }
      after  { features.deactivate_owner(:premium_vms, owner) }
      it { expect(data[:vm_type]).to eq(:premium) }
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
    let(:payload)   { { 'pull_request' => { 'head' => { 'ref' => 'head_branch', 'sha' => '12345' } } } }

    before :each do
      request.stubs(:base_commit).returns('0cd9ff')
      request.stubs(:head_commit).returns('62aaef')
    end

    it 'data' do
      expect(data).to eq(
        type: :test,
        vm_type: :default,
        queue: 'builds.gce',
        config: {
          rvm: '1.8.7',
          gemfile: 'Gemfile.rails'
        },
        env_vars: [
          { name: 'BAR', value: 'bar', public: true }
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
          debug_options: {},
          pull_request_head_branch: 'head_branch',
          pull_request_head_sha: '12345'
        },
        source: {
          id: build.id,
          number: '2',
          event_type: 'pull_request'
        },
        repository: {
          id: repo.id,
          github_id: 549743,
          slug: 'svenfuchs/gem-release',
          source_url: 'https://github.com/svenfuchs/gem-release.git',
          api_url: 'https://api.github.com/repos/svenfuchs/gem-release',
          last_build_id: 1,
          last_build_started_at: '2016-01-01T10:00:00Z',
          last_build_finished_at: '2016-01-01T11:00:00Z',
          last_build_number: '2',
          last_build_duration: 60,
          last_build_state: 'passed',
          default_branch: 'branch',
          description: 'description',
        },
        ssh_key: nil,
        timeouts: {
          hard_limit: 180 * 60, # worker handles timeouts in seconds
          log_silence: 20 * 60
        },
        cache_settings: s3,
        oauth_token: nil
      )
    end

    describe 'from the same repository' do
      before { Request.any_instance.stubs(:same_repo_pull_request?).returns(true) }

      it 'enables secure env variables' do
        expect(data[:job][:secure_env_enabled]).to eq(true)
        expect(data[:env_vars].size).to eql(2)
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
        before { repo.update_attributes!(private: false) }
        include_examples 'does not include an ssh key'
      end

      describe 'on a private repo' do
        before { repo.update_attributes!(private: true) }
        include_examples 'includes an ssh key'
      end
    end

    describe 'on enterprise' do
      before { config[:enterprise] = true }

      describe 'on a public repo' do
        before { repo.update_attributes!(private: false) }
        include_examples 'includes an ssh key'
      end

      describe 'on a private repo' do
        before { repo.update_attributes!(private: true) }
        include_examples 'includes an ssh key'
      end
    end
  end
end
