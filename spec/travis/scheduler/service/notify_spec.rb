describe Travis::Scheduler::Service::Notify do
  let(:queue)   { 'builds.gce' }
  let(:job)     { FactoryGirl.create(:job, state: :queued, queue: queue) }
  let(:data)    { { job: { id: job.id } } }
  let(:context) { Travis::Scheduler.context }
  let(:service) { described_class.new(context, data) }
  let(:amqp)    { Travis::Amqp::Publisher.any_instance }
  let(:live)    { Travis::Live }

  it 'publishes to rabbit' do
    amqp.expects(:publish).with(instance_of(Hash), properties: { type: 'test', persistent: true })
    service.run
  end

  it 'publishes to live' do
    live.expects(:push).with(instance_of(Hash), event: 'job:queued')
    service.run
  end

  context do
    let(:queue) { 'builds.linux' }

    before { context.config[:queue_redirections] = { 'builds.linux' => 'builds.gce' } }
    before { service.run }

    it 'redirects the queue' do
      expect(job.reload.queue).to eq 'builds.gce'
    end
  end
end
