require 'spec_helper'
require 'travis/scheduler/services/limit/default'

describe Travis::Scheduler::Services::Limit::Default do
  include Travis::Testing::Stubs

  let(:jobs)  { 12.times.map { stub_test } }
  let(:limit) { described_class.new(org, jobs) }
  let(:redis) { Travis::Scheduler.redis }

  before do
    jobs.each do |job|
      job.repository.stubs(:settings).returns OpenStruct.new({:restricts_number_of_builds? => false})
    end
    @config = Travis.config.limit
  end

  after do
    Travis.config.limit = @config
  end

  it 'allows the first 5 jobs if none are running by default' do
    limit.stubs(running: 0)
    expect(limit.queueable).to eq(jobs[0, 5])
  end

  it 'allows one job if 4 are running by default' do
    limit.stubs(running: 4)
    expect(limit.queueable).to eq(jobs[0, 1])
  end

  describe 'boost' do
    before { redis.set("scheduler.owner.limit.#{org.login}", 10) }
    after  { redis.del("scheduler.owner.limit.#{org.login}") }

    it 'allows the first 10 jobs if the org has a boost of 10 jobs' do
      limit.stubs(running: 0)
      expect(limit.queueable).to eq(jobs[0, 10])
    end
  end

  describe 'config.limit' do
    it 'allows the first 8 jobs if the org is allowed 8 jobs' do
      Travis.config.limit = { by_owner: { org.login => 8 } }
      limit.stubs(running: 0)
      expect(limit.queueable).to eq(jobs[0, 8])
    end

    it 'allows all jobs if the limit is set to -1' do
      Travis.config.limit = { by_owner: { org.login => -1 } }
      limit.stubs(running: 12)
      expect(limit.queueable).to eq(jobs)
    end
  end

  it 'gives a readable report' do
    limit.stubs(running: 3)
    expect(limit.report).to eq({ total: 12, running: 3, max: 5, queueable: 2 })
  end

  describe "limit per repository" do
    before do
      jobs.each do |job|
        job.repository.stubs(:settings).returns OpenStruct.new({:restricts_number_of_builds? => true, :maximum_number_of_builds => 3})
      end
    end

    it 'schedules the maximum number of builds for a single repository' do
      limit.stubs(running: 1)
      limit.stubs(running_jobs: [OpenStruct.new(repository_id: test.repository_id)])
      expect(limit.queueable.size).to eq(2)
    end

    it "schedules jobs for other repositories" do
      test = stub_test(repository_id: 11111, repository: stub_repo)
      test.repository.stubs(:settings).returns OpenStruct.new({:restricts_number_of_builds? => false})
      limit.stubs(running: 1)
      limit.stubs(running_jobs: [OpenStruct.new(repository_id: test.repository_id)])
      expect(limit.queueable.size).to eq(3)
    end

    it "doesn't fail for repositories with no running jobs and restriction enabled" do
      test = stub_test(repository_id: 11111, repository: stub_repo)
      limit.stubs(running: 1)
      limit.stubs(running_jobs: [OpenStruct.new(repository_id: test.repository_id)])
      expect(limit.queueable.size).to eq(3)
    end

    it "doesn't allow for a repository maximum higher than the total maximum" do
      jobs.each do |job|
        job.repository.stubs(:settings).returns OpenStruct.new({:restricts_number_of_builds? => true, :maximum_number_of_builds => 12})
        expect(limit.queueable.size).to eq(5)
      end
    end
  end
end
