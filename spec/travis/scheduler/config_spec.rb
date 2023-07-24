# frozen_string_literal: true

describe Travis::Scheduler::Config do
  subject { config.log_level }

  let(:config) { Travis::Scheduler::Config.load }

  describe 'given no env var' do
    it { is_expected.to eq :info }
  end

  describe 'given TRAVIS_LOG_LEVEL=debug' do
    env TRAVIS_LOG_LEVEL: :debug

    it { is_expected.to eq :debug }
  end

  describe 'queues' do
    describe 'with travis_config being set' do
      env travis_config: YAML.dump('queues' => ['queue' => 'from_keychain'])

      it { expect(config.queues[0]).to eq queue: 'from_keychain' }
    end

    describe 'with generic env vars being set' do
      env TRAVIS_QUEUES_0_QUEUE: 'builds.gce',
          TRAVIS_QUEUES_0_SUDO: 'true',
          TRAVIS_QUEUES_0_GROUP: 'legacy',
          TRAVIS_QUEUES_1_QUEUE: 'builds.gce',
          TRAVIS_QUEUES_1_SUDO: 'true',
          TRAVIS_QUEUES_2_QUEUE: 'builds.ec2',
          TRAVIS_QUEUES_2_SUDO: 'false',
          TRAVIS_QUEUES_2_DIST: 'trusty',
          TRAVIS_QUEUES_3_QUEUE: 'builds.docker',
          TRAVIS_QUEUES_3_SUDO: 'false',
          TRAVIS_QUEUES_4_QUEUE: 'builds.gce',
          TRAVIS_QUEUES_4_DIST: 'trusty'

      it { expect(config.queues[0]).to eq queue: 'builds.gce', sudo: true, group: 'legacy' }
      it { expect(config.queues[1]).to eq queue: 'builds.gce', sudo: true }
      it { expect(config.queues[2]).to eq queue: 'builds.ec2', sudo: false, dist: 'trusty' }
      it { expect(config.queues[3]).to eq queue: 'builds.docker', sudo: false }
      it { expect(config.queues[4]).to eq queue: 'builds.gce', dist: 'trusty' }
    end

    describe 'with a nested array' do
      env TRAVIS_QUEUES_0_QUEUE: 'builds.gce',
          TRAVIS_QUEUES_0_SERVICES_0: 'docker'

      it { expect(config.queues[0]).to eq queue: 'builds.gce', services: ['docker'] }
    end
  end
end
