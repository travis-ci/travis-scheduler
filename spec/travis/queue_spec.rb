describe Travis::Queue do
  let(:context)    { Travis::Scheduler.context }
  let(:recently)   { 7.days.ago }
  let(:created_at) { Time.now }
  let(:slug)       { 'travis-ci/travis-ci' }
  let(:config)     { {} }
  let(:percent)    { 0 }

  let(:owner)      { FactoryGirl.build(:user, login: slug.split('/').first) }
  let(:repo)       { FactoryGirl.build(:repo, owner: owner, owner_name: owner.login, name: slug.split('/').last, created_at: created_at) }
  let(:job)        { FactoryGirl.build(:job, config: config, owner: owner, repository: repo) }
  let(:queue)      { described_class.new(job, context.config, logger).select }

  let(:force_precise_sudo_required?) { false }
  let(:force_linux_sudo_required?) { false }

  before do
    Travis::Scheduler.logger.stubs(:info)
    context.config.queue.default = 'builds.default'
    context.config.queues = [
      { queue: 'builds.rails', slug: 'rails/rails' },
      { queue: 'builds.mac_osx', os: 'osx' },
      { queue: 'builds.docker', sudo: false, dist: 'precise' },
      { queue: 'builds.ec2', sudo: false, dist: 'trusty' },
      { queue: 'builds.ec2', sudo: false, dist: 'xenial' },
      { queue: 'builds.gce', services: %w(docker) },
      { queue: 'builds.gce', dist: 'trusty', sudo: 'required' },
      { queue: 'builds.gce', dist: 'precise', sudo: 'required' },
      { queue: 'builds.gce', dist: 'xenial', sudo: 'required' },
      { queue: 'builds.gce', resources: { gpu: true } },
      { queue: 'builds.cloudfoundry', owner: 'cloudfoundry' },
      { queue: 'builds.clojure', language: 'clojure' },
      { queue: 'builds.erlang', language: 'erlang' },
      { queue: 'builds.mac_stable', osx_image: 'stable' },
      { queue: 'builds.mac_beta', osx_image: 'beta' },
      { queue: 'builds.new-foo', language: 'foo', percentage: percent },
      { queue: 'builds.old-foo', language: 'foo' }
    ]
    Travis::Queue::Sudo
      .any_instance
      .stubs(:force_precise_sudo_required?)
      .returns(force_precise_sudo_required?)
    Travis::Queue::Sudo
      .any_instance
      .stubs(:force_linux_sudo_required?)
      .returns(force_linux_sudo_required?)
  end

  after do
    context.config.queues = nil
    context.config.docker_default_queue_cutoff = nil
    context.redis.flushall
  end

  describe 'by default' do
    let(:slug) { 'travis-ci/travis-ci' }
    it { expect(queue).to eq 'builds.default' }
  end

  describe 'by default, with a docker cutoff' do
    before do
      context.config.docker_default_queue_cutoff = '2015-01-01'
    end
    let(:config) { { language: 'php', os: 'linux', group: 'stable', dist: 'precise' } }
    it { expect(queue).to eq 'builds.docker' }
  end

  describe 'by app config' do
    describe 'by repo slug' do
      let(:slug) { 'rails/rails' }
      it { expect(queue).to eq 'builds.rails' }
    end

    describe 'by owner name' do
      let(:slug) { 'cloudfoundry/bosh' }
      it { expect(queue).to eq 'builds.cloudfoundry' }
    end
  end

  describe 'by job config' do
    describe 'by language' do
      let(:config) { { language: 'clojure' } }
      it { expect(queue).to eq 'builds.clojure' }
    end

    describe 'by language (passed as an array)' do
      let(:config) { { language: ['clojure'] } }
      it { expect(queue).to eq 'builds.clojure' }
    end
  end

  describe 'by educational status' do
    before { owner.stubs(:education?).returns(true) }

    describe 'on org' do
      describe 'returns the default queue for educational repositories, too' do
        it { expect(queue).to eq 'builds.default' }
      end

      describe 'returns the queue matching configuration for educational repository' do
        let(:config) { { os: 'osx' } }
        it { expect(queue).to eq 'builds.mac_osx' }
      end
    end

    describe 'on com' do
      before { context.config.host = 'travis-ci.com' }
      after  { context.config.host = 'travis-ci.org' }

      describe 'returns the default queue by default for educational repositories' do
        it { expect(queue).to eq 'builds.default' }
      end

      describe 'returns the queue matching configuration for educational repository' do
        let(:config) { { os: 'osx' } }
        it { expect(queue).to eq 'builds.mac_osx' }
      end
    end
  end

  describe 'by job config :os' do
    describe 'by os' do
      let(:config) { { :os => 'osx'} }
      it { expect(queue).to eq 'builds.mac_osx' }
    end

    describe 'by os (trumps language)' do
      let(:config) { { language: 'clojure', os: 'osx' } }
      it { expect(queue).to eq 'builds.mac_osx' }
    end
  end

  describe 'by job config :services' do
    describe 'by service' do
      let(:config) { { services: %w(redis docker postgresql) } }
      it { expect(queue).to eq 'builds.gce' }
    end

    describe 'by service (trumps language)' do
      let(:config) { { language: 'clojure', services: %w(redis docker postgresql) } }
      it { expect(queue).to eq 'builds.gce' }
    end
  end

  describe 'by job config sudo: false' do
    describe 'by sudo' do
      let(:config) { { sudo: false, dist: 'precise' } }
      it { expect(queue).to eq 'builds.docker' }
    end

    describe 'by sudo (trumps language)' do
      let(:config) { { language: 'clojure', sudo: false, dist: 'precise' } }
      it { expect(queue).to eq 'builds.docker' }
    end
  end

  describe 'by job config :dist' do
    describe 'dist: trusty' do
      let(:config) { { dist: 'trusty' } }
      it { expect(queue).to eq 'builds.gce' }
    end

    describe 'dist: unknown' do
      let(:config) { { dist: 'unknown' } }
      it { expect(queue).to eq 'builds.default' }
    end
  end

  describe 'by job config osx_image' do
    describe 'osx_image: stable' do
      let(:config) { { osx_image: 'stable' } }
      it { expect(queue).to eq 'builds.mac_stable' }
    end

    describe 'osx_image: beta' do
      let(:config) { { osx_image: 'beta' } }
      it { expect(queue).to eq 'builds.mac_beta' }
    end
  end

  describe 'given a percentage' do
    describe '0 percent' do
      let(:percent) { 0 }
      let(:config)  { { language: 'foo' } }
      it { expect(queue).to eq 'builds.old-foo' }
    end

    describe '100 percent' do
      let(:percent) { 100 }
      let(:config)  { { language: 'foo' } }
      it { expect(queue).to eq 'builds.new-foo' }
    end
  end

  describe 'resources.gpu: true routes to gce' do
    let(:config) { { resources: { gpu: true } } }
    before { Travis::Features.activate_repository(:vm_config, repo) }
    it { expect(queue).to eq 'builds.gce' }
  end

  describe 'pooled' do
    env TRAVIS_SITE: 'com',
        POOL_QUEUES: 'gce',
        POOL_SUFFIX: 'foo'

    let(:config) { { dist: 'trusty' } }

    it { expect(queue).to eq 'builds.gce-foo' }
  end

  [
    { queue: 'builds.docker', config: { dist: 'precise' } },
    { queue: 'builds.docker', config: { dist: 'precise' }, education: true },
    { queue: 'builds.ec2', config: { dist: 'trusty' } },
    { queue: 'builds.ec2', config: { dist: 'trusty' }, education: true },
    { queue: 'builds.ec2', config: { dist: 'xenial' } },
    { queue: 'builds.ec2', config: { dist: 'xenial' }, education: true },
    { queue: 'builds.gce', config: { dist: 'precise' }, created_at: NOWISH - 30.days },
    { queue: 'builds.gce', config: { dist: 'precise' }, force_linux_sudo_required: true },
    { queue: 'builds.gce', config: { dist: 'precise', sudo: false }, force_linux_sudo_required: true },
    { queue: 'builds.gce', config: { dist: 'precise' }, force_precise_sudo_required: true },
    { queue: 'builds.gce', config: { dist: 'precise', sudo: false }, force_precise_sudo_required: true },
    { queue: 'builds.gce', config: { dist: 'precise', script: 'sudo huh' } },
    { queue: 'builds.gce', config: { dist: 'precise', sudo: 'required' } },
    { queue: 'builds.gce', config: { dist: 'precise', sudo: true } },
    { queue: 'builds.gce', config: { dist: 'trusty' }, created_at: NOWISH - 30.days },
    { queue: 'builds.gce', config: { dist: 'trusty' }, force_linux_sudo_required: true },
    { queue: 'builds.gce', config: { dist: 'trusty', sudo: false }, force_linux_sudo_required: true },
    { queue: 'builds.gce', config: { dist: 'trusty', script: 'sudo huh' } },
    { queue: 'builds.gce', config: { dist: 'trusty', sudo: 'required' } },
    { queue: 'builds.gce', config: { dist: 'trusty', sudo: true } },
    { queue: 'builds.gce', config: { dist: 'xenial' }, created_at: NOWISH - 30.days },
    { queue: 'builds.gce', config: { dist: 'xenial' }, force_linux_sudo_required: true },
    { queue: 'builds.gce', config: { dist: 'xenial', sudo: false }, force_linux_sudo_required: true },
    { queue: 'builds.gce', config: { dist: 'xenial', script: 'sudo huh' } },
    { queue: 'builds.gce', config: { dist: 'xenial', sudo: 'required' } },
    { queue: 'builds.gce', config: { dist: 'xenial', sudo: true } },
  ].map { |qc| Support::Queues::QueueCase.new(qc) }.each do |c|
    describe c.to_s do
      before do
        context.config.docker_default_queue_cutoff = c.cutoff
        context.config.host = c.host
        owner.stubs(:education?).returns(c.education?)
      end

      after do
        context.config.docker_default_queue_cutoff = nil
        context.config.host = 'travis-ci.org'
      end

      let(:config) { c.config }
      let(:created_at) { c.created_at }
      let(:force_precise_sudo_required?) { c.force_precise_sudo_required? }
      let(:force_linux_sudo_required?) { c.force_linux_sudo_required? }

      it { expect(queue).to eq(c.queue) }
    end
  end
end
