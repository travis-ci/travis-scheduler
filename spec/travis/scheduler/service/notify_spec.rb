describe Travis::Scheduler::Service::Notify do
  let(:job)     { FactoryGirl.create(:job, state: :queued) }
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

  describe 'sets the queue' do
    let(:config) { { language: 'objective-c', os: 'osx', osx_image: 'xcode8', group: 'stable', dist: 'osx'} }
    let(:job)    { FactoryGirl.create(:job, state: :queued, config: config) }

    before { ENV['QUEUE_SELECTION_OWNERS'] = 'svenfuchs' }
    before { context.config.queues = [{ queue: 'builds.mac_osx', os: 'osx' }] }
    before { service.run }

    it { expect(job.reload.queue).to eq 'builds.mac_osx' }
    it { expect(log).to include "W Queue selection evaluated to builds.mac_osx, but the current queue is builds.gce for job=#{job.id}" }
    it { expect(log).to include "I Setting queue to builds.mac_osx for job=#{job.id}" }
  end

  # TODO confirm we don't need queue redirection any more
  context do
    let(:queue) { 'builds.linux' }

    before { context.config[:queue_redirections] = { 'builds.linux' => 'builds.gce' } }
    before { service.run }

    it 'redirects the queue' do
      expect(job.reload.queue).to eq 'builds.gce'
    end
  end

  describe 'does not raise on encoding issues ("\xC3" from ASCII-8BIT to UTF-8)' do
    let(:config) { { global_env: ["SECURE GH_USER_NAME=Max Nöthe".force_encoding('ASCII-8BIT')] } }
    before { job.update_attributes!(config: config) }
    it { expect { service.run }.to_not raise_error }
  end
end
