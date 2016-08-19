require 'spec_helper'
require 'travis/scheduler/payloads/worker'

describe Travis::Scheduler::Services::EnqueueJobs do
  include Travis::Testing::Stubs

  let(:job)     { stub_job(state: :created, queue: 'builds.gce', update_attributes!: nil) }
  let(:service) { described_class.new }

  describe 'run' do
    let(:publisher) { stub(publish: true) }

    before :each do
      settings = OpenStruct.new(
        restricts_number_of_builds?: false,
        env_vars: []
      )
      job.repository.stubs(:settings).returns(settings)
      scope = stub('scope')
      scope.stubs(:all).returns([job])
      Job.stubs(:queueable).returns(scope)
      service.stubs(:publisher).returns(publisher)
      Sidekiq::Client.stubs(:push)
    end

    it 'enqueues queueable jobs' do
      job.expects(:update_attributes!).with(state: :queued, queued_at: Time.now)
      service.run
    end

    it 'publishes queueable jobs' do
      Sidekiq::Client.expects(:push).with(
        'queue' => :scheduler,
        'class' => 'Travis::Scheduler::Worker',
        'args'  => [:notify, job: { id: job.id }]
      )
      service.run
    end

    it 'keeps a report of enqueued jobs' do
      service.run
      expect(service.reports).to eq({ 'svenfuchs (user)' => { total: 1, running: 0, max: 5, queueable: 1 } })
    end

    describe 'given queue redirection config' do
      before do
        Travis::Scheduler.config.queue_redirections['builds.linux'] = 'builds.gce'
      end

      it 'keeps the job queue if it does not match' do
        job.stubs(:queue).returns('builds.macosx')
        job.expects(:queue=).never
        service.run
      end

      it 'redirects the job queue if it matches' do
        job.stubs(:queue).returns('builds.linux')
        job.expects(:queue=).with('builds.gce')
        job.expects(:save!)
        service.run
      end
    end
  end

  # describe 'Instrument' do
  #   let(:publisher) { Travis::Notification::Publisher::Memory.new }
  #   let(:event)     { publisher.events.last }
  #   let(:reports)   { { 'svenfuchs (user)' => { total: 1, running: 0, max: 5, queueable: 1 } } }

  #   before :each do
  #     Travis::Notification.publishers.replace([publisher])
  #     service.stubs(:enqueue_all)
  #     service.stubs(:reports).returns(reports)
  #     service.run
  #   end

  #   it 'publishes a event' do
  #     event.should publish_instrumentation_event(
  #       event: 'travis.scheduler.services.enqueue_jobs.run:completed',
  #       message: "Travis::Scheduler::Services::EnqueueJobs#run:completed enqueued:\n  svenfuchs: total: 1, running: 0, max: 5, queueable: 1",
  #       data: {
  #         reports: reports
  #       }
  #     )
  #   end
  # end

  describe 'Logging' do
    before do
      Travis.logger.stubs(:info)
    end

    it 'logs the enqueue' do
      service.stubs(:publish)
      Travis.logger.expects(:info).with("enqueueing slug=svenfuchs/minimal job_id=1").once
      service.send(:enqueue, [job])
    end
  end
end
