require 'spec_helper'

describe Travis::Scheduler::Services::EnqueueJobs do
  include Travis::Testing::Stubs

  let(:service) { described_class.new }

  describe 'run' do
    let(:publisher) { stub(publish: true) }
    let(:test)      { stub_test(state: :created, enqueue: nil) }

    before :each do
      settings = OpenStruct.new(
        restricts_number_of_builds?: false,
        env_vars: []
      )
      test.repository.stubs(:settings).returns(settings)
      scope = stub('scope')
      scope.stubs(:all).returns([test])
      Job.stubs(:queueable).returns(scope)
      service.stubs(:publisher).returns(publisher)
    end

    it 'enqueues queueable jobs' do
      test.expects(:enqueue)
      service.run
    end

    it 'publishes queueable jobs' do
      payload = Travis::Scheduler::Services::Helpers::WorkerPayload.new(test).data
      publisher.expects(:publish).with(payload, properties: { type: 'test', persistent: true })
      service.run
    end

    it 'keeps a report of enqueued jobs' do
      service.run
      service.reports.should == { 'svenfuchs' => { total: 1, running: 0, max: 5, queueable: 1 } }
    end
  end

  describe 'Instrument' do
    let(:publisher) { Travis::Notification::Publisher::Memory.new }
    let(:event)     { publisher.events.last }
    let(:reports)   { { 'svenfuchs' => { total: 1, running: 0, max: 5, queueable: 1 } } }

    before :each do
      Travis::Notification.publishers.replace([publisher])
      service.stubs(:enqueue_all)
      service.stubs(:reports).returns(reports)
      service.run
    end

    it 'publishes a event' do
      event.should publish_instrumentation_event(
        event: 'travis.scheduler.services.enqueue_jobs.run:completed',
        message: "Travis::Scheduler::Services::EnqueueJobs#run:completed enqueued:\n  svenfuchs: total: 1, running: 0, max: 5, queueable: 1",
        data: {
          reports: reports
        }
      )
    end
  end

  describe 'Logging' do
    it 'logs the enqueue' do
      service.stubs(:publish)
      Travis.logger.expects(:info).with("enqueueing slug=svenfuchs/minimal job_id=42.1").once
      service.send(:enqueue, [stub_job])
    end
  end
end
