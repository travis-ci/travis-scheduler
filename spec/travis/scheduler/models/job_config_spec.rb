require 'spec_helper'

describe Job::Config do
  let(:repo)    { FactoryGirl.create(:repository) }
  let(:secure)  { repo.key.secure }
  subject       { described_class.decrypt(config, secure, options) }

  def encrypt(string)
    secure.encrypt(string)
  end

  shared_examples_for :common do
    describe 'the original config remains untouched' do
      let(:config) { { env: env, global_env: env } }
      let(:env)    { [{ secure: 'invalid' }] }

      it do
        subject
        expect(config).to eql(
          env:        [{ secure: 'invalid' }],
          global_env: [{ secure: 'invalid' }]
        )
      end
    end

    describe 'regular vars remain untouched' do
      let(:config) { { rvm: '1.8.7', env: 'FOO=foo', global_env: 'BAR=bar' } }

      it do
        should eql(rvm: '1.8.7', env: ['FOO=foo'], global_env: ['BAR=bar'])
      end
    end

    describe 'with a nil env' do
      let(:config) { { rvm: '1.8.7', env: nil, global_env: nil } }
      it { should eql(config) }
    end

    describe 'with a [nil] env' do
      let(:config) { { rvm: '1.8.7', env: [ nil ], global_env: [ nil ] } }
      it { should eql({ rvm: '1.8.7', env: [], global_env: [] }) }
    end
  end

  describe 'with secure env enabled' do
    let(:options) { { secure_env: true } }

    include_examples :common

    describe 'decrypts env vars' do
      let(:config) { { env: env, global_env: env } }
      let(:env)    { [encrypt('FOO=foo')] }

      it do
        should eql(
          env:        ['SECURE FOO=foo'],
          global_env: ['SECURE FOO=foo']
        )
      end
    end

    describe 'can mix secure and normal env vars' do
      let(:config) { { env: env, global_env: env } }
      let(:env)    { [encrypt('FOO=foo'), 'BAR=bar'] }

      it do
        should eql(
          env:        ['SECURE FOO=foo', 'BAR=bar'],
          global_env: ['SECURE FOO=foo', 'BAR=bar']
        )
      end
    end

    describe 'normalizes env vars which are hashes to strings' do
      let(:config) { { env: env, global_env: env } }
      let(:env)    { [{ FOO: 'foo', BAR: 'bar' }, encrypt('BAZ=baz')] }

      it do
        should eql(
          env:        ["FOO=foo BAR=bar", "SECURE BAZ=baz"],
          global_env: ["FOO=foo BAR=bar", "SECURE BAZ=baz"]
        )
      end
    end
  end

  describe 'with secure env disabled' do
    let(:options) { { secure_env: false } }

    include_examples :common

    describe 'removes secure env vars' do
      let(:config) { { rvm: '1.8.7', env: env, global_env: env } }
      let(:env)    { ['FOO=foo', 'BAR=bar', encrypt('BAZ=baz')] }

      it do
        should eql(
          rvm:        '1.8.7',
          env:        ["FOO=foo", 'BAR=bar'],
          global_env: ["FOO=foo", 'BAR=bar']
        )
      end
    end
  end

  describe 'with full_addons being false' do
    let(:options) { { full_addons: false } }

    describe 'removes addons if it is not a hash' do
      let(:config) { { rvm: '1.8.7', addons: [] } }
      it { should eql(rvm: '1.8.7') }
    end

    [:sauce_connect].each do |name|
      describe "removes the #{name} addon" do
        let(:config) { { addons: { name => :config } } }
        it { should be_empty }
      end
    end

    Job::Config::Normalize::WHITELISTED_ADDONS.map(&:to_sym).each do |name|
      describe "keeps the #{name} addon" do
        let(:config) { { addons: { name => :config } } }
        it { should eql(config) }
      end
    end

    describe 'jwt encrypted env var' do
      let(:var)    { 'SAUCE_ACCESS_KEY=foo' }
      let(:config) { { addons: { jwt: encrypt(var) } } }
      it { should eql(addons: { jwt: var }) }
    end
  end

  describe 'with full_addons being true' do
    let(:options) { { full_addons: true } }

    describe 'decrypts addons config' do
      let(:config) { { addons: { sauce_connect: { access_key: encrypt('foo') } } } }

      it do
        should eql(addons: { sauce_connect: { access_key: 'foo' } })
      end
    end

    describe 'decrypts deploy addon config' do
      let(:config) { { deploy: { foo: encrypt('foobar') } } }

      it do
        should eql(addons: { deploy: { foo: 'foobar' } })
      end
    end
  end
end
