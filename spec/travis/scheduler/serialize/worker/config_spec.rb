# frozen_string_literal: true

describe Travis::Scheduler::Serialize::Worker::Config do
  subject       { described_class.decrypt(config, secure, options) }

  let(:repo)    { FactoryBot.create(:repository) }
  let(:secure)  { Travis::SecureConfig.new(repo.key) }

  def encrypt(string)
    secure.encrypt(string)
  end

  shared_examples_for 'common' do
    describe 'the original config remains untouched' do
      let(:config) { { env:, global_env: env } }
      let(:env)    { [{ secure: 'invalid' }] }

      before { subject }

      it do
        expect(config).to eql(
          env: [{ secure: 'invalid' }],
          global_env: [{ secure: 'invalid' }]
        )
      end
    end

    describe 'string vars' do
      let(:config) { { rvm: '1.8.7', env: 'FOO=foo', global_env: 'BAR=bar' } }

      it { is_expected.to eql(rvm: '1.8.7', env: ['FOO=foo'], global_env: ['BAR=bar']) }
    end

    describe 'hash vars' do
      let(:config) { { rvm: '1.8.7', env: { FOO: 'foo' }, global_env: { BAR: 'bar' } } }

      it { is_expected.to eql(rvm: '1.8.7', env: ['FOO=foo'], global_env: ['BAR=bar']) }
    end

    describe 'with a nil env' do
      let(:config) { { rvm: '1.8.7', env: nil, global_env: nil } }

      it { is_expected.to eql(rvm: '1.8.7') }
    end

    describe 'with a [nil] env' do
      let(:config) { { rvm: '1.8.7', env: [nil], global_env: [nil] } }

      it { is_expected.to eql({ rvm: '1.8.7', env: [], global_env: [] }) }
    end
  end

  describe 'with secure env enabled' do
    let(:options) { { secure_env: true } }

    include_examples 'common'

    describe 'decrypts env string vars' do
      let(:config) { { env:, global_env: env } }
      let(:env)    { [encrypt('FOO=foo')] }

      it { is_expected.to eql env: ['SECURE FOO=foo'], global_env: ['SECURE FOO=foo'] }
    end

    describe 'decrypts env hash vars' do
      let(:config) { { env:, global_env: env } }
      let(:env)    { [FOO: encrypt('foo')] }

      it { is_expected.to eql env: ['SECURE FOO=foo'], global_env: ['SECURE FOO=foo'] }
    end

    describe 'can mix secure and normal env vars' do
      let(:config) { { env:, global_env: env } }
      let(:env)    { [encrypt('FOO=foo'), 'BAR=bar'] }

      it { is_expected.to eql env: ['SECURE FOO=foo', 'BAR=bar'], global_env: ['SECURE FOO=foo', 'BAR=bar'] }
    end

    describe 'normalizes env vars which are hashes to strings' do
      let(:config) { { env:, global_env: env } }
      let(:env)    { [{ FOO: 'foo', BAR: 'bar' }, encrypt('BAZ=baz')] }

      it {
        expect(subject).to eql env: ['FOO=foo', 'BAR=bar', 'SECURE BAZ=baz'], global_env: ['FOO=foo', 'BAR=bar', 'SECURE BAZ=baz']
      }
    end

    describe 'decrypts vault secure token' do
      let(:config) { { vault: { token: { secure: encrypt('my_key') } } } }

      it { is_expected.to eql vault: { token: 'my_key' } }
    end

    describe 'clears vault unsecure token' do
      let(:config) { { vault: { token: 'my_key' } } }

      it { is_expected.to eql vault: {} }
    end
  end

  describe 'with secure env disabled' do
    let(:options) { { secure_env: false } }

    include_examples 'common'

    describe 'removes secure env vars' do
      let(:config) { { rvm: '1.8.7', env:, global_env: env } }
      let(:env)    { ['FOO=foo', 'BAR=bar', encrypt('BAZ=baz')] }

      it { is_expected.to eql rvm: '1.8.7', env: ['FOO=foo', 'BAR=bar'], global_env: ['FOO=foo', 'BAR=bar'] }
    end
  end

  describe 'with full_addons being false' do
    let(:options) { { full_addons: false } }

    describe 'removes addons if it is not a hash' do
      let(:config) { { rvm: '1.8.7', addons: [] } }

      it { is_expected.to eql(rvm: '1.8.7') }
    end

    [:sauce_connect].each do |name|
      describe "removes the #{name} addon" do
        let(:config) { { addons: { name => :config } } }

        it { is_expected.to be_empty }
      end
    end

    described_class::Addons::SAFE.map(&:to_sym).delete_if { |name| name == :jwt }.each do |name|
      describe "keeps the #{name} addon" do
        let(:config) { { addons: { name => :config } } }

        it { is_expected.to eql(config) }
      end
    end

    describe 'jwt encrypted env var' do
      let(:var)    { 'SAUCE_ACCESS_KEY=foo012345678901234565789' }
      let(:config) { { addons: { jwt: encrypt(var) } } }

      it { is_expected.to eql(addons: { jwt: Array(var) }) }
    end
  end

  describe 'with full_addons being true' do
    let(:options) { { full_addons: true } }

    describe 'decrypts addons config' do
      let(:config) { { addons: { sauce_connect: { access_key: encrypt('foo') } } } }

      it { is_expected.to eql(addons: { sauce_connect: { access_key: 'foo' } }) }
    end

    describe 'decrypts deploy addon config' do
      let(:config) { { deploy: { foo: encrypt('foobar') } } }

      it { is_expected.to eql(addons: { deploy: { foo: 'foobar' } }) }
    end
  end

  describe 'jwt addon with encrypted data' do
    let(:var)    { "SAUCE_ACCESS_KEY=#{sauce_access_key}" }
    let(:config) { { addons: { sauce_connect: { username: 'sauce_connect_user' }, jwt: encrypt(var) } } }

    shared_examples_for 'includes the decrypted jwt addon config' do
      describe 'jwt encrypted env var' do
        it { expect(subject[:addons][:jwt]).to eq Array(var) }
      end
    end

    shared_examples_for 'does not include the decrypted jwt addon config' do
      describe 'jwt encrypted env var' do
        it { expect(subject[:addons][:jwt]).to eq [] }
      end
    end

    context 'with long SAUCE_ACCESS_KEY' do
      let(:sauce_access_key) { 'foo012345678901234565789' }

      describe 'on a push request' do
        let(:options) { { full_addons: true } }

        include_examples 'includes the decrypted jwt addon config'
      end

      describe 'on a pull request' do
        let(:options) { { full_addons: false } }

        include_examples 'includes the decrypted jwt addon config'
      end
    end

    context 'with short SAUCE_ACCESS_KEY' do
      let(:sauce_access_key) { 'foo' }

      describe 'on a push request' do
        let(:options) { { full_addons: true } }

        include_examples 'does not include the decrypted jwt addon config'
      end

      describe 'on a pull request' do
        let(:options) { { full_addons: false } }

        include_examples 'does not include the decrypted jwt addon config'
      end
    end

    context 'with non-safelisted env var' do
      let(:var) { 'ARBITRARY_ACCESS_KEY=foo012345678901234565789' }

      describe 'on a push request' do
        let(:options) { { full_addons: true } }

        include_examples 'does not include the decrypted jwt addon config'
      end

      describe 'on a pull request' do
        let(:options) { { full_addons: false } }

        include_examples 'does not include the decrypted jwt addon config'
      end
    end
  end
end
