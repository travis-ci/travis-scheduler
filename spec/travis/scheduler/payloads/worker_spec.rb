require 'spec_helper'
require 'travis/settings/encrypted_column'
require 'travis/scheduler/models/repository/settings'
require 'travis/scheduler/payloads/worker'

describe Travis::Scheduler::Payloads::Worker do
  include Travis::Testing::Stubs

  let(:data) { described_class.new(job).data }
  let(:foo)  { Travis::Settings::EncryptedColumn.new(use_prefix: false).dump('bar') }
  let(:bar)  { Travis::Settings::EncryptedColumn.new(use_prefix: false).dump('baz') }
  let(:cache_settings_linux) {
    {
      access_key_id:      'ACCESS_KEY_ID',
      secret_access_key:  'SECRET_ACCESS_KEY',
      bucket_name:        'cache_bucket'
    }
  }

  let(:settings) do
    Repository::Settings.load({
      'env_vars' => [
        { 'name' => 'FOO', 'value' => foo },
        { 'name' => 'BAR', 'value' => bar, 'public' => true }
      ],
      'timeout_hard_limit' => 180,
      'timeout_log_silence' => 20
    })
  end

  before :each do
    Travis.config.encryption.key = 'secret' * 10
    Travis.config.cache_settings = {
      :'builds.linux' => cache_settings_linux
    }
    job.repository.stubs(:settings).returns(settings)
  end

  describe 'for a push request' do
    before :each do
      commit.stubs(:pull_request?).returns(false)
      commit.stubs(:ref).returns(nil)
      Travis::Scheduler::Support::Features.activate_owner(:cache_settings, job.repository.owner)
    end

    it 'contains the expected data' do
      expect(data.except('job', 'build', 'repository')).to eq(
        'type' => 'test',
        'vm_type' => 'default',
        'config' => {
          'rvm' => '1.8.7',
          'gemfile' => 'test/Gemfile.rails-2.3.x'
        },
        'queue' => 'builds.linux',
        'ssh_key' => nil,
        'source' => {
          'id' => 1,
          'number' => 2,
          'event_type' => 'push'
        },
        'env_vars' => [
          { 'name' => 'FOO', 'value' => 'bar', 'public' => false },
          { 'name' => 'BAR', 'value' => 'baz', 'public' => true }
        ],
        'timeouts' => {
          'hard_limit' => 180 * 60, # worker handles timeouts in seconds
          'log_silence' => 20 * 60
        },
        'cache_settings' => cache_settings_linux
      )
    end

    it 'contains the expected job data' do
      expect(data['job']).to eq(
        'id' => 1,
        'number' => '2.1',
        'commit' => '62aae5f70ceee39123ef',
        'commit_range' => '0cd9ffaab2c4ffee...62aae5f70ceee39123ef',
        'commit_message' => 'the commit message',
        'branch' => 'master',
        'ref' => nil,
        'tag' => nil,
        'pull_request' => false,
        'state' => 'passed',
        'secure_env_enabled' => true,
        'debug_options' => {}
      )
    end

    it 'contains the expected build data (legacy)' do
      # TODO legacy. remove this once workers respond to a 'job' key
      expect(data['build']).to eq(
        'id' => 1,
        'number' => '2.1',
        'commit' => '62aae5f70ceee39123ef',
        'commit_range' => '0cd9ffaab2c4ffee...62aae5f70ceee39123ef',
        'commit_message' => 'the commit message',
        'branch' => 'master',
        'ref'    => nil,
        'tag' => nil,
        'pull_request' => false,
        'state' => 'passed',
        'secure_env_enabled' => true,
        'debug_options' => {}
      )
    end

    it 'contains the expected repo data' do
      expect(data['repository']).to eq(
        'id' => 1,
        'slug' => 'svenfuchs/minimal',
        'source_url' => 'git://github.com/svenfuchs/minimal.git',
        'api_url' => 'https://api.github.com/repos/svenfuchs/minimal',
        'last_build_id' => 1,
        'last_build_started_at' => json_format_time(Time.now.utc - 1.minute),
        'last_build_finished_at' => json_format_time(Time.now.utc),
        'last_build_number' => 2,
        'last_build_duration' => 60,
        'last_build_state' => 'passed',
        'description' => 'the repo description',
        'default_branch' => 'master',
        'github_id' => 549743
      )
    end

    it 'includes the tag name' do
      request.stubs(:tag_name).returns 'v1.2.3'
      expect(data['job']['tag']).to eq('v1.2.3')
    end

    describe 'with the premium_vms feature flag active' do
      let(:features) { Travis::Scheduler::Support::Features }
      let(:repo)     { job.repository }
      let(:owner)    { job.repository.owner }

      after do
        features.deactivate_repository(:premium_vms, repo)
        features.deactivate_owner(:premium_vms, owner)
      end

      describe 'for the repo' do
        before { features.activate_repository(:premium_vms, repo) }
        it { expect(data['vm_type']).to eq('premium') }
      end

      describe 'for the owner' do
        before { features.activate_owner(:premium_vms, owner) }
        it { expect(data['vm_type']).to eq('premium') }
      end
    end
  end

  describe 'for a debug build request' do
    let(:debug_options) { {"stage"=>"before_install", "previous_state"=>"failed", "created_by"=>"svenfuchs", "quiet"=>"false"} }
    before :each do
      job.stubs(:debug_options).returns(debug_options)
    end

    it 'contains expected data' do
      expect(data['job']['debug_options']).to eq(debug_options)
    end
  end

  describe 'for a pull request' do
    before :each do
      commit.stubs(:pull_request?).returns(true)
      commit.stubs(:ref).returns('refs/pull/180/merge')
      commit.stubs(:pull_request_number).returns(180)
      job.stubs(:secure_env?).returns(false)
      job.source.stubs(:event_type).returns('pull')
      request.stubs(:pull_request?).returns(true)
      request.stubs(:pull_request_head_branch).returns("feature-branch")
      request.stubs(:pull_request_head_sha).returns("1234567890abcdef")
    end

    it 'contains the expected data' do
      expect(data.except('job', 'build', 'repository')).to eq(
        'type' => 'test',
        'vm_type' => 'default',
        'config' => {
          'rvm' => '1.8.7',
          'gemfile' => 'test/Gemfile.rails-2.3.x'
        },
        'queue' => 'builds.linux',
        'ssh_key' => nil,
        'source' => {
          'id' => 1,
          'number' => 2,
          'event_type' => 'pull'
        },
        'env_vars' => [
          { 'name' => 'BAR', 'value' => 'baz', 'public' => true }
        ],
        'timeouts' => {
          'hard_limit' => 180 * 60, # worker handles timeouts in seconds
          'log_silence' => 20 * 60
        },
        'cache_settings' => cache_settings_linux
      )
    end

    it 'contains the expected job data' do
      expect(data['job']).to eq(
        'id' => 1,
        'number' => '2.1',
        'commit' => '62aae5f70ceee39123ef',
        'commit_range' => '0cd9ffaab2c4ffee...62aae5f70ceee39123ef',
        'commit_message' => 'the commit message',
        'branch' => 'master',
        'ref'    => 'refs/pull/180/merge',
        'tag' => nil,
        'pull_request' => 180,
        'state' => 'passed',
        'secure_env_enabled' => false,
        'debug_options' => {},
        'pull_request_head_branch' => 'feature-branch',
        'pull_request_head_sha' => '1234567890abcdef'
      )
    end

    it 'contains the expected build data (legacy)' do
      # TODO legacy. remove this once workers respond to a 'job' key
      expect(data['build']).to eq(
        'id' => 1,
        'number' => '2.1',
        'commit' => '62aae5f70ceee39123ef',
        'commit_range' => '0cd9ffaab2c4ffee...62aae5f70ceee39123ef',
        'commit_message' => 'the commit message',
        'branch' => 'master',
        'ref'    => 'refs/pull/180/merge',
        'tag' => nil,
        'pull_request' => 180,
        'state' => 'passed',
        'secure_env_enabled' => false,
        'debug_options' => {},
        'pull_request_head_branch' => 'feature-branch',
        'pull_request_head_sha' => '1234567890abcdef'
      )
    end

    it 'contains the expected repo data' do
      expect(data['repository']).to eq(
        'id' => 1,
        'slug' => 'svenfuchs/minimal',
        'source_url' => 'git://github.com/svenfuchs/minimal.git',
        'api_url' => 'https://api.github.com/repos/svenfuchs/minimal',
        'last_build_id' => 1,
        'last_build_started_at' => json_format_time(Time.now.utc - 1.minute),
        'last_build_finished_at' => json_format_time(Time.now.utc),
        'last_build_number' => 2,
        'last_build_duration' => 60,
        'last_build_state' => 'passed',
        'description' => 'the repo description',
        'default_branch' => 'master',
        'github_id' => 549743
      )
    end

    describe 'from the same repository' do
      before do
        job.stubs(:secure_env?).returns(true)
      end

      it 'enables secure env variables' do
        expect(data['job']['secure_env_enabled']).to eq(true)
        expect(data['env_vars'].size).to eql(2)
      end
    end
  end

  describe 'addons' do
    let(:repo)   { FactoryGirl.build(:repository) }
    let(:job)    { FactoryGirl.build(:job, repository: repo, config: config) }
    let(:var)    { 'SAUCE_ACCESS_KEY=foo' }
    let(:config) { { addons: { jwt: encrypt(var) } } }

    def encrypt(string)
      repo.key.secure.encrypt(string)
    end

    shared_examples_for 'includes the decrypted jwt addon config' do
      describe 'jwt encrypted env var' do
        before  { job.stubs(:config).returns(config) }
        it { expect(data['config'][:addons][:jwt]).to eq var }
      end
    end

    describe 'on a push request' do
      before { job.source.stubs(:event_type).returns('push') }
      it { expect(job.full_addons?).to eq true }
      it { expect(job.secure_env?).to eq true }
      include_examples 'includes the decrypted jwt addon config'
    end

    describe 'on a pull request' do
      before { job.source.stubs(:event_type).returns('pull_request') }
      it { expect(job.full_addons?).to eq false }
      it { expect(job.secure_env?).to eq false }
      include_examples 'includes the decrypted jwt addon config'
    end
  end

  describe 'for a build with string timeouts' do
    let(:settings) do
      Repository::Settings.load({
        'env_vars' => [
          { 'name' => 'FOO', 'value' => foo },
          { 'name' => 'BAR', 'value' => bar, 'public' => true }
        ],
        'timeout_hard_limit' => '180',
        'timeout_log_silence' => '20'
      })
    end

    it 'converts them to ints' do
      expect(data['timeouts']).to eq({'hard_limit' => 180*60, 'log_silence' => 20*60})
    end
  end

  describe 'ssh_key' do
    let(:repo) { job.repository }
    before { repo.key.stubs(:private_key).returns('repo key') }
    after  { Travis.config.enterprise = false }

    shared_examples_for 'does not include an ssh key' do
      it { expect(data['ssh_key']).to eq nil }
    end

    shared_examples_for 'includes an ssh key' do
      describe 'from the repo settings' do
        before { repo.settings.ssh_key = { value: 'settings key' } }
        it { expect(data['ssh_key']).to eq('source' => 'repository_settings', 'value' => 'settings key', 'encoded' => false) }
      end

      describe 'from the job' do
        before { job.stubs(:ssh_key).returns('job key') }
        it { expect(data['ssh_key']).to eq('source' => 'travis_yaml', 'value' => 'job key', 'encoded' => true) }
      end

      describe 'from the repo' do
        it { expect(data['ssh_key']).to eq('source' => 'default_repository_key', 'value' => 'repo key', 'encoded' => false) }
      end
    end

    describe 'outside enterprise' do
      before { Travis.config.enterprise = false }

      describe 'on a public repo' do
        before { repo.stubs(:public?).returns(true) }
        include_examples 'does not include an ssh key'
      end

      describe 'on a private repo' do
        before { repo.stubs(:public?).returns(false) }
        include_examples 'includes an ssh key'
      end
    end

    describe 'on enterprise' do
      before { Travis.config.enterprise = true }

      describe 'on a public repo' do
        before { repo.stubs(:public?).returns(true) }
        include_examples 'includes an ssh key'
      end

      describe 'on a private repo' do
        before { repo.stubs(:public?).returns(false) }
        include_examples 'includes an ssh key'
      end
    end
  end

  def json_format_time(time)
    time.strftime('%Y-%m-%dT%H:%M:%SZ')
  end
end

