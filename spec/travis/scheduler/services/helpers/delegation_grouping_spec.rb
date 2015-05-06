require 'spec_helper'

describe Travis::Scheduler::Services::Helpers::DelegationGrouping do
  include Travis::Testing::Stubs

  let(:jobs)  { 10.times.map { stub_test } }
  let(:limit) { described_class.new(organization) }

  describe "with delegated owners" do
    let(:config) do
      {
        "travis-ci":
          - "travis-infrastructure"
          - "travis-pro"
        }
      }
    end

    let(:limit) do
      described_class.new(config)
    end

    before do
      Organization.create!(login: 'travis-ci')
      Organization.create!(login: 'travis-pro')
      Organization.create!(login: 'travis-infrastructure')
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
        Travis.config.queue.limit[:delegate] = {
          'travis-pro' => 'travis-ci',
          'roidrage' => 'travis-ci'
        }
        subscription.update_column(:selected_plan, 'travis-ci-five-builds')
      end

      after do
        Travis.config.queue.limit[:delegate] = nil
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
          Travis.config.queue.limit[:by_owner]['travis-ci'] = 2
        end

        after do
          Travis.config.queue.limit.by_owner['travis-ci'] = nil
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
