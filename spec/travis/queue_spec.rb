describe Travis::Queue do
  let(:context)    { Travis::Scheduler.context }
  let(:recently)   { 7.days.ago }
  let(:created_at) { Time.now }
  let(:slug)       { 'travis-ci/travis-ci' }
  let(:config)     { {} }
  let(:percent)    { 0 }

  let(:owner)      { FactoryGirl.build(:user, login: slug.split('/').first) }
  let(:repo)       { FactoryGirl.build(:repo, owner: owner, owner_name: owner.login, name: slug.split('/').last, created_at: created_at) }
  let(:job)        { FactoryGirl.build(:job, config: config, repository: repo) }
  let(:queue)      { described_class.new(job, context.config, logger).select }

  before do
    context.config.queues = [
      { queue: 'builds.rails', slug: 'rails/rails' },
      { queue: 'builds.mac_osx', os: 'osx' },
      { queue: 'builds.docker', sudo: false },
      { queue: 'builds.gce', services: %w(docker) },
      { queue: 'builds.gce', dist: 'trusty' },
      { queue: 'builds.cloudfoundry', owner: 'cloudfoundry' },
      { queue: 'builds.clojure', language: 'clojure' },
      { queue: 'builds.erlang', language: 'erlang' },
      { queue: 'builds.mac_stable', osx_image: 'stable' },
      { queue: 'builds.mac_beta', osx_image: 'beta' },
      { queue: 'builds.new-foo', language: 'foo', percentage: percent },
      { queue: 'builds.old-foo', language: 'foo' }
    ]
  end

  after do
    context.config.queues = nil
    context.config.docker_default_queue_cutoff = nil
    context.redis.flushall
  end

  describe 'by default' do
    let(:slug) { 'travis-ci/travis-ci' }
    it { expect(queue).to eq 'builds.gce' }
  end

  describe 'by default, with a docker cutoff' do
    before do
      context.config.docker_default_queue_cutoff = '2015-01-01'
      Travis::Queue::Docker.any_instance.stubs(:force_precise_sudo_required?).returns(false)
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
        it { expect(queue).to eq 'builds.gce' }
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
        it { expect(queue).to eq 'builds.gce' }
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
      let(:config) { { sudo: false } }
      it { expect(queue).to eq 'builds.docker' }
    end

    describe 'by sudo (trumps language)' do
      let(:config) { { language: 'clojure', sudo: false } }
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
      it { expect(queue).to eq 'builds.gce' }
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

  describe 'on .org' do
    before { context.config.docker_default_queue_cutoff = recently.to_s }
    after  { context.config.docker_default_queue_cutoff = nil }

    describe 'sudo: nil' do
      let(:config) { {} }

      describe 'when the account is educational' do
        before { owner.stubs(:education?).returns(true) }

        describe 'when sudo is detected' do
          let(:config) { { script: 'sudo echo whatever' } }

          describe 'when the repo created_at is before cutoff' do
            let(:created_at) { recently - 7.days }
            it { expect(queue).to eq 'builds.gce' }
          end

          describe 'when the repo created_at is after cutoff' do
            let(:created_at) { Time.now }
            it { expect(queue).to eq 'builds.gce' }
          end
        end

        describe 'when sudo is not detected' do
          describe 'when the repo created_at is before cutoff' do
            let(:created_at) { recently - 7.days }
            it { expect(queue).to eq 'builds.gce' }
          end

          describe 'when the repo created_at is after cutoff' do
            let(:created_at) { Time.now }
            it { expect(queue).to eq 'builds.docker' }
          end
        end
      end

      describe 'when the account is not educational' do
        describe 'when sudo is detected' do
          let(:config) { { script: 'sudo echo whatever' } }

          describe 'when the repo created_at is before cutoff' do
            let(:created_at) { recently - 7.days }
            it { expect(queue).to eq 'builds.gce' }
          end

          describe 'when the repo created_at is after cutoff' do
            let(:created_at) { Time.now }
            it { expect(queue).to eq 'builds.gce' }
          end
        end

        describe 'when sudo is not detected' do
          describe 'when the repo created_at is before cutoff' do
            let(:created_at) { recently - 7.days }
            it { expect(queue).to eq 'builds.gce' }
          end

          describe 'when the repo created_at is after cutoff' do
            let(:created_at) { Time.now }
            it { expect(queue).to eq 'builds.docker' }
          end
        end
      end
    end

    describe 'sudo: false' do
      let(:config) { { sudo: false } }

      describe 'when the account is educational' do
        before { owner.stubs(:education?).returns(true) }

        describe 'when sudo is detected' do
          let(:config) { { script: 'sudo echo whatever' } }

          describe 'when the repo created_at is before cutoff' do
            let(:created_at) { recently - 7.days }
            it { expect(queue).to eq 'builds.gce' }
          end

          describe 'when the repo created_at is after cutoff' do
            let(:created_at) { Time.now }
            it { expect(queue).to eq 'builds.gce' }
          end
        end

        describe 'when sudo is not detected' do
          describe 'when the repo created_at is before cutoff' do
            let(:created_at) { recently - 7.days }
            it { expect(queue).to eq 'builds.docker' }
          end

          describe 'when the repo created_at is after cutoff' do
            let(:created_at) { Time.now }
            it { expect(queue).to eq 'builds.docker' }
          end
        end
      end

      describe 'when the account is not educational' do
        describe 'when sudo is detected' do
          let(:config) { { script: 'sudo echo whatever' } }

          describe 'when the repo created_at is before cutoff' do
            let(:created_at) { recently - 7.days }
            it { expect(queue).to eq 'builds.gce' }
          end

          describe 'when the repo created_at is after cutoff' do
            let(:created_at) { Time.now }
            it { expect(queue).to eq 'builds.gce' }
          end
        end

        describe 'when sudo is not detected' do
          describe 'when the repo created_at is before cutoff' do
            let(:created_at) { recently - 7.days }
            it { expect(queue).to eq 'builds.docker' }
          end

          describe 'when the repo created_at is after cutoff' do
            let(:created_at) { Time.now }
            it { expect(queue).to eq 'builds.docker' }
          end
        end
      end
    end

    [true, 'required'].each do |sudo|
      describe "sudo: #{sudo}" do
        let(:config) { { sudo: sudo } }

        describe 'when the account is educational' do
          before { owner.stubs(:education?).returns(true) }

          describe 'when sudo is detected' do
            let(:config) { { script: 'sudo echo whatever' } }

            describe 'when the repo created_at is before cutoff' do
              let(:created_at) { recently - 7.days }
              it { expect(queue).to eq 'builds.gce' }
            end

            describe 'when the repo created_at is after cutoff' do
              let(:created_at) { Time.now }
              it { expect(queue).to eq 'builds.gce' }
            end
          end

          describe 'when sudo is not detected' do
            describe 'when the repo created_at is before cutoff' do
              let(:created_at) { recently - 7.days }
              it { expect(queue).to eq 'builds.gce' }
            end

            describe 'when the repo created_at is after cutoff' do
              let(:created_at) { Time.now }
              it { expect(queue).to eq 'builds.gce' }
            end
          end
        end

        describe 'when the account is not educational' do
          describe 'when sudo is detected' do
            let(:config) { { script: 'sudo echo whatever' } }

            describe 'when the repo created_at is before cutoff' do
              let(:created_at) { recently - 7.days }
              it { expect(queue).to eq 'builds.gce' }
            end

            describe 'when the repo created_at is after cutoff' do
              let(:created_at) { Time.now }
              it { expect(queue).to eq 'builds.gce' }
            end
          end

          describe 'when sudo is not detected' do
            describe 'when the repo created_at is before cutoff' do
              let(:created_at) { recently - 7.days }
              it { expect(queue).to eq 'builds.gce' }
            end

            describe 'when the repo created_at is after cutoff' do
              let(:created_at) { Time.now }
              it { expect(queue).to eq 'builds.gce' }
            end
          end
        end
      end
    end
  end

  describe 'on .com' do
    before { context.config.host = 'travis-ci.com' }
    after  { context.config.host = 'travis-ci.org' }

    before { context.config.docker_default_queue_cutoff = recently.to_s }
    after  { context.config.docker_default_queue_cutoff = nil }

    describe 'sudo: nil' do
      let(:config) { {} }

      describe 'when the account is educational' do
        before { owner.stubs(:education?).returns(true) }

        describe 'when sudo is detected' do
          let(:config) { { script: 'sudo echo whatever' } }

          describe 'when the repo created_at is before cutoff' do
            let(:created_at) { recently - 7.days }
            it { expect(queue).to eq 'builds.gce' }
          end

          describe 'when the repo created_at is after cutoff' do
            let(:created_at) { Time.now }
            it { expect(queue).to eq 'builds.gce' }
          end
        end

        describe 'when sudo is not detected' do
          describe 'when the repo created_at is before cutoff' do
            let(:created_at) { recently - 7.days }
            it { expect(queue).to eq 'builds.gce' }
          end

          describe 'when the repo created_at is after cutoff' do
            let(:created_at) { Time.now }
            it { expect(queue).to eq 'builds.docker' }
          end
        end
      end

      describe 'when the account is not educational' do
        describe 'when sudo is detected' do
          let(:config) { { script: 'sudo echo whatever' } }

          describe 'when the repo created_at is before cutoff' do
            let(:created_at) { recently - 7.days }
            it { expect(queue).to eq 'builds.gce' }
          end

          describe 'when the repo created_at is after cutoff' do
            let(:created_at) { Time.now }
            it { expect(queue).to eq 'builds.gce' }
          end
        end

        describe 'when sudo is not detected' do
          describe 'when the repo created_at is before cutoff' do
            let(:created_at) { recently - 7.days }
            it { expect(queue).to eq 'builds.gce' }
          end

          describe 'when the repo created_at is after cutoff' do
            let(:created_at) { Time.now }
            it { expect(queue).to eq 'builds.docker' }
          end
        end
      end
    end

    describe 'sudo: false' do
      let(:config) { { sudo: false } }

      describe 'when the account is educational' do
        before { owner.stubs(:education?).returns(true) }

        describe 'when sudo is detected' do
          let(:config) { { script: 'sudo echo whatever' } }

          describe 'when the repo created_at is before cutoff' do
            let(:created_at) { recently - 7.days }
            it { expect(queue).to eq 'builds.gce' }
          end

          describe 'when the repo created_at is after cutoff' do
            let(:created_at) { Time.now }
            it { expect(queue).to eq 'builds.gce' }
          end
        end

        describe 'when sudo is not detected' do
          describe 'when the repo created_at is before cutoff' do
            let(:created_at) { recently - 7.days }
            it { expect(queue).to eq 'builds.docker' }
          end

          describe 'when the repo created_at is after cutoff' do
            let(:created_at) { Time.now }
            it { expect(queue).to eq 'builds.docker' }
          end
        end
      end

      describe 'when the account is not educational' do
        describe 'when sudo is detected' do
          let(:config) { { script: 'sudo echo whatever' } }

          describe 'when the repo created_at is before cutoff' do
            let(:created_at) { recently - 7.days }
            it { expect(queue).to eq 'builds.gce' }
          end

          describe 'when the repo created_at is after cutoff' do
            let(:created_at) { Time.now }
            it { expect(queue).to eq 'builds.gce' }
          end
        end

        describe 'when sudo is not detected' do
          describe 'when the repo created_at is before cutoff' do
            let(:created_at) { recently - 7.days }
            it { expect(queue).to eq 'builds.docker' }
          end

          describe 'when the repo created_at is after cutoff' do
            let(:created_at) { Time.now }
            it { expect(queue).to eq 'builds.docker' }
          end
        end
      end
    end

    [true, 'required'].each do |sudo|
      describe "sudo: #{sudo}" do
        let(:config) { { sudo: sudo } }

        describe 'when the account is educational' do
          before { owner.stubs(:education?).returns(true) }

          describe 'when sudo is detected' do
            let(:config) { { script: 'sudo echo whatever' } }

            describe 'when the repo created_at is before cutoff' do
              let(:created_at) { recently - 7.days }
              it { expect(queue).to eq 'builds.gce' }
            end

            describe 'when the repo created_at is after cutoff' do
              let(:created_at) { Time.now }
              it { expect(queue).to eq 'builds.gce' }
            end
          end

          describe 'when sudo is not detected' do
            describe 'when the repo created_at is before cutoff' do
              let(:created_at) { recently - 7.days }
              it { expect(queue).to eq 'builds.gce' }
            end

            describe 'when the repo created_at is after cutoff' do
              let(:created_at) { Time.now }
              it { expect(queue).to eq 'builds.gce' }
            end
          end
        end

        describe 'when the account is not educational' do
          describe 'when sudo is detected' do
            let(:config) { { script: 'sudo echo whatever' } }

            describe 'when the repo created_at is before cutoff' do
              let(:created_at) { recently - 7.days }
              it { expect(queue).to eq 'builds.gce' }
            end

            describe 'when the repo created_at is after cutoff' do
              let(:created_at) { Time.now }
              it { expect(queue).to eq 'builds.gce' }
            end
          end

          describe 'when sudo is not detected' do
            describe 'when the repo created_at is before cutoff' do
              let(:created_at) { recently - 7.days }
              it { expect(queue).to eq 'builds.gce' }
            end

            describe 'when the repo created_at is after cutoff' do
              let(:created_at) { Time.now }
              it { expect(queue).to eq 'builds.gce' }
            end
          end
        end
      end
    end
  end
end
