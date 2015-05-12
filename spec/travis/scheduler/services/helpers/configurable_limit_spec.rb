require 'spec_helper'

describe Travis::Scheduler::Services::Helpers::ConfigurableLimit do
  include Travis::Testing::Stubs

  let(:jobs)  { 10.times.map { stub_test } }
  let(:limit) { described_class.new(organization, jobs) }

  let(:organization) do
    Organization.new(login: 'travis-ci', subscription: subscription)
  end

  let(:user) do
    User.new(login: 'roidrage')
  end

  let(:subscription) do
    Subscription.new({
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
      limit.queueable.size.should == 2
    end

    it "runs five jobs with the next biggest plan" do
      organization.subscription.selected_plan = "travis-ci-five-builds"
      limit.stubs(:running).returns(0)
      limit.queueable.size.should == 5
    end

    it "handles semi-expired subscriptions" do
      organization.subscription.valid_to = 20.hours.from_now
      limit.stubs(:running).returns(0)
      limit.queueable.size.should == 2
    end

    it "runs one build if there's no subscription" do
      organization.subscription = nil
      limit.stubs(:running).returns(0)
      limit.queueable.size.should == 1
    end

    it "uses the default with an unknown plan" do
      organization.subscription.selected_plan = "blah"
      limit.stubs(:running).returns(0)
      limit.queueable.size.should == 1
    end

    it "uses the default when the subscription isn't valid" do
      organization.subscription.cc_token = nil
      organization.subscription.valid_to = nil
      limit.stubs(:running).returns(0)
      limit.queueable.size.should == 1
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
      limit.queueable.size.should == 4
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
      limit.queueable.size.should == 1
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
      limit.delegate.should == organization
    end

    it "calculates the jobs based on the limit by the owner" do
      limit.stubs(:running).returns(0)
      limit.queueable.size.should == 2
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
        limit.delegatees.should include(roidrage)
        limit.delegatees.should include(travispro)
      end

      it "checks all running jobs for the delegatees" do
        job = Job::Test.new(owner: roidrage, state: 'started', repository: Repository.new(owner: roidrage))
        job.save validate: false
        job = Job::Test.new(owner: travispro, state: 'started', repository: Repository.new(owner: travispro))
        job.save validate: false
        limit.running.should == 2
      end

      it "returns a number of jobs that are runnable based on the overall delegatees" do
        job = Job::Test.new(owner: roidrage, state: 'started', repository: Repository.new(owner: roidrage))
        job.save validate: false
        job = Job::Test.new(owner: travispro, state: 'started', repository: Repository.new(owner: travispro))
        job.save validate: false
        limit.queueable.size.should == 3
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
        limit.queueable.size.should == 0
      end

      describe "with a custom limit" do
        before do
          Travis.config.limit[:by_owner]['travis-ci'] = 2
        end

        after do
          Travis.config.limit.by_owner['travis-ci'] = nil
        end

        it "allows overriding the delegate limit in the configuration" do
          job = Job::Test.new(owner: roidrage, state: 'started', repository: Repository.new(owner: roidrage))
          job.save validate: false
          job = Job::Test.new(owner: travispro, state: 'started', repository: Repository.new(owner: travispro))
          job.save validate: false
          job = Job::Test.new(owner: organization, state: 'queued', repository: Repository.new(owner: organization))
          job.save validate: false
          limit.max_jobs_from_container_account.should == 2
        end
      end
    end
  end
end
