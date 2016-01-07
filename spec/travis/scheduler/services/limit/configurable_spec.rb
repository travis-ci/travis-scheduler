require 'spec_helper'
require 'travis/scheduler/models/repository'

describe Travis::Scheduler::Services::Limit::Configurable do
  include Travis::Testing::Stubs

  let(:jobs)  { 10.times.map { |id| stub_job(id: id) } }
  let(:limit) { described_class.new(organization, jobs) }
  let(:redis) { Travis::Scheduler.redis }

  let(:organization) do
    Organization.new(login: 'travis-ci', subscription: subscription)
  end

  let(:user) do
    User.new(login: 'roidrage')
  end

  let(:subscription) do
    Subscription.create!({
      selected_plan: 'travis-ci-two-builds',
      cc_token: 'empty',
      valid_to: 14.days.from_now
    })
  end

  before do
    @config = Travis.config.limit

    Travis.config[:limit] = {
      default: 1,
      by_owner: {}
    }

    Travis.config[:plans] = {
      'travis-ci-two-builds' => 2,
      'travis-ci-five-builds' => 5
    }
  end

  after do
    Travis.config.limit = @config
  end

  describe "with a subscription" do
    it "runs two jobs based on the subscription" do
      limit.stubs(:running).returns(0)
      expect(limit.queueable.size).to eq(2)
    end

    it "runs five jobs with the next biggest plan" do
      organization.subscription.selected_plan = "travis-ci-five-builds"
      limit.stubs(:running).returns(0)
      expect(limit.queueable.size).to eq(5)
    end

    it "handles semi-expired subscriptions" do
      organization.subscription.valid_to = 20.hours.from_now
      limit.stubs(:running).returns(0)
      expect(limit.queueable.size).to eq(2)
    end

    it "runs one build if there's no subscription" do
      organization.subscription = nil
      limit.stubs(:running).returns(0)
      expect(limit.queueable.size).to eq(1)
    end

    it "uses the default with an unknown plan" do
      organization.subscription.selected_plan = "blah"
      limit.stubs(:running).returns(0)
      expect(limit.queueable.size).to eq(1)
    end

    it "uses the default when the subscription isn't valid" do
      organization.subscription.cc_token = nil
      organization.subscription.valid_to = nil
      limit.stubs(:running).returns(0)
      expect(limit.queueable.size).to eq(1)
    end
  end

  describe 'with a boost' do
    before { redis.set("scheduler.owner.limit.travis-ci", 10) }
    after  { redis.del("scheduler.owner.limit.travis-ci") }

    it 'allows the first 10 jobs if the org has a boost of 10 jobs' do
      limit.stubs(running: 0)
      expect(limit.queueable).to eq(jobs[0, 10])
    end
  end

  describe "with configuration" do
    before do
      Travis.config.limit.by_owner['travis-ci'] = 4
    end

    after do
      Travis.config.limit.by_owner['travis-ci'] = nil
    end

    it "overrides plans with the configuration" do
      limit.stubs(:running).returns(0)
      expect(limit.queueable.size).to eq(4)
    end
  end

  describe "without plans" do
    before do
      @plans = Travis.config.plans
      Travis.config.plans = nil
    end

    after do
      Travis.config.plans = @plans
    end

    it "falls back to the default" do
      limit.stubs(:running).returns(0)
      expect(limit.queueable.size).to eq(1)
    end
  end

  describe "with delegated plans" do
    let(:travispro) {
      Organization.create!(login: 'travis-pro')
    }

    let(:limit) {
      described_class.new(travispro, jobs)
    }

    before do
      travispro
      organization.save!
      Travis.config.limit[:delegate] = {
        'travis-pro' => 'travis-ci'
      }
    end

    after do
      Travis.config.limit[:delegate] = nil
    end

    it "sets the delegate" do
      expect(limit.delegate).to eq(organization)
    end

    it "calculates the jobs based on the limit by the owner" do
      limit.stubs(:running).returns(0)
      expect(limit.queueable.size).to eq(2)
    end

    describe "with multiple delegatees" do
      let(:roidrage) {
        User.create!(login: 'roidrage')
      }
      before do
        roidrage
        Travis.config.limit[:delegate] = {
          'travis-pro' => 'travis-ci',
          'roidrage' => 'travis-ci'
        }
        subscription.update_column(:selected_plan, 'travis-ci-five-builds')
      end

      after do
        Travis.config.limit[:delegate] = nil
      end

      it "determines all delegatees" do
        expect(limit.delegatees).to include(roidrage)
        expect(limit.delegatees).to include(travispro)
      end

      it "checks all running jobs for the delegatees" do
        job = Job::Test.new(owner: roidrage, state: 'started', repository: Repository.new(owner: roidrage))
        job.save validate: false
        job = Job::Test.new(owner: travispro, state: 'started', repository: Repository.new(owner: travispro))
        job.save validate: false
        expect(limit.running).to eq(2)
      end

      it "returns a number of jobs that are runnable based on the overall delegatees" do
        job = Job::Test.new(owner: roidrage, state: 'started', repository: Repository.new(owner: roidrage))
        job.save validate: false
        job = Job::Test.new(owner: travispro, state: 'started', repository: Repository.new(owner: travispro))
        job.save validate: false
        expect(limit.queueable.size).to eq(3)
      end

      it "checks the number of builds for the container organization" do
        job = Job::Test.new(owner: roidrage, state: 'started', repository: Repository.new(owner: roidrage))
        job.save validate: false
        job = Job::Test.new(owner: travispro, state: 'started', repository: Repository.new(owner: travispro))
        job.save validate: false
        job = Job::Test.new(owner: organization, state: 'queued', repository: Repository.new(owner: organization))
        job.save validate: false
        job = Job::Test.new(owner: organization, state: 'started', repository: Repository.new(owner: organization))
        job.save validate: false
        job = Job::Test.new(owner: organization, state: 'started', repository: Repository.new(owner: organization))
        job.save validate: false
        expect(limit.queueable.size).to eq(0)
      end

      describe 'with a boost' do
        let!(:travis_ci)    { Organization.create!(login: 'travis-ci') }
        let!(:organization) { Organization.create!(login: 'travis-pro') }

        after  { redis.del("scheduler.owner.limit.travis-ci") }
        before { redis.set("scheduler.owner.limit.travis-ci", 10) }

        it 'allows the first 10 jobs if the org has a boost of 10 jobs' do
          expect(limit.queueable.size).to eq(10)
        end
      end

      describe "with a custom limit" do
        before do
          Travis.config.limit[:by_owner]['travis-ci'] = 2
        end

        after do
          Travis.config.limit.by_owner['travis-ci'] = nil
        end

        it "allows overriding the delegate limit in the configuration" do
          Job::Test.create!(owner: roidrage, state: 'started', repository: Repository.new(owner: roidrage))
          Job::Test.create!(owner: travispro, state: 'started', repository: Repository.new(owner: travispro))
          Job::Test.create!(owner: organization, state: 'queued', repository: Repository.new(owner: organization))
          expect(limit.max_jobs_from_container_account).to eq(2)
        end
      end
    end
  end
end
