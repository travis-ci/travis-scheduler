describe Travis::Scheduler::Service::Notify do
  let(:job)     { FactoryBot.create(:job, state: :queued, queued_at: Time.parse('2016-01-01T10:30:00Z'), config: {}) }
  let(:data)    { { job: { id: job.id } } }
  let(:context) { Travis::Scheduler.context }
  let(:service) { described_class.new(context, data) }
  let(:amqp)    { Travis::Amqp::Publisher.any_instance }
  let(:jobs)    { Travis::JobBoard }
  let(:live)    { Travis::Live }
  let(:auth)    { Base64.strict_encode64('user:pass').chomp }
  let(:url)     { 'https://job-board.travis-ci.org/jobs/add' }
  let(:status)  { 201 }
  let(:body)    { 'Created' }
  let(:authorize_build_url) { "http://localhost:9292/users/#{job.owner.id}/plan" }

  before { stub_request(:post, url).to_return(status:, body:) }
  before do
    stub_request(:get, authorize_build_url).to_return(
      body: MultiJson.dump(plan_name: 'two_concurrent_plan', hybrid: true, free: false, status: 'subscribed',
                           metered: false)
    )
  end

  describe 'with rollout job_board not enabled' do
    before { disable_rollout('job_board', job.owner) }

    it 'publishes to rabbit' do
      amqp.expects(:publish).with(instance_of(Hash), properties: { type: 'test', persistent: true })
      service.run
    end
  end

  describe 'with rollout job_board enabled' do
    before { enable_rollout('job_board', job.owner) }

    shared_examples_for 'raises' do
      it 'raises' do
        expect { service.run }.to raise_error(Faraday::ClientError)
      end
    end

    shared_examples_for 'raises_server' do
      it 'raises_server' do
        expect { service.run }.to raise_error(Faraday::ServerError)
      end
    end

    shared_examples_for 'does not raise' do
      it 'does not raise' do
        expect { service.run }.to_not raise_error
      end
    end

    def rescueing
      yield
    rescue StandardError => e
    end

    describe 'publishes to job_board' do
      describe 'with a valid request' do
        it 'sends the expected request' do
          service.run
          expect(WebMock).to(have_requested(:post, url).with do |request|
            body = JSON.parse(request.body)
            expect(body['@type']).to                    eq 'job'
            expect(body['id']).to                       eq job.id
            expect(body['data']).to                     be_a Hash
            expect(request.headers['Authorization']).to eq "Basic #{auth}"
            expect(request.headers['Content-Type']).to  eq 'application/json'
            expect(request.headers['Travis-Site']).to   eq 'org'
          end)
        end

        include_examples 'does not raise'

        it 'logs' do
          service.run
          expect(log).to include "I POST to https://job-board.travis-ci.org/jobs/add responded 201 (job #{job.id} created)"
        end
      end

      describe 'when the job already exists in job board' do
        let(:status) { 204 }
        let(:body)   { nil }

        include_examples 'does not raise'

        it 'logs' do
          service.run
          expect(log).to include "W POST to https://job-board.travis-ci.org/jobs/add responded 204 (job #{job.id} already exists)"
        end
      end

      describe 'when the request is invalid' do
        let(:status) { 400 }
        let(:body)   { nil }

        include_examples 'raises'

        it 'logs' do
          rescueing { service.run }
          expect(log).to include "E POST to https://job-board.travis-ci.org/jobs/add responded 400 (bad request: #{body})"
        end
      end

      describe 'when the site header is missing' do
        let(:status) { 412 }
        let(:body)   { nil }

        include_examples 'raises'

        it 'logs' do
          rescueing { service.run }
          expect(log).to include 'E POST to https://job-board.travis-ci.org/jobs/add responded 412 (site header missing)'
        end
      end

      describe 'when the authorization header is missing' do
        let(:status) { 401 }
        let(:body)   { nil }

        include_examples 'raises'

        it 'logs' do
          rescueing { service.run }
          expect(log).to include 'E POST to https://job-board.travis-ci.org/jobs/add responded 401 (auth header missing)'
        end
      end

      describe 'when the authorization header is invalid' do
        let(:status) { 403 }
        let(:body)   { nil }

        include_examples 'raises'

        it 'logs' do
          rescueing { service.run }
          expect(log).to include 'E POST to https://job-board.travis-ci.org/jobs/add responded 403 (auth header invalid)'
        end
      end

      describe 'when job board raises' do
        let(:status) { 500 }
        let(:body)   { nil }

        include_examples 'raises_server'

        it 'logs' do
          rescueing { service.run }
          expect(log).to include 'E POST to https://job-board.travis-ci.org/jobs/add responded 500 (internal error)'
        end
      end
    end
  end

  it 'publishes to live' do
    live.expects(:push).with(instance_of(Hash), event: 'job:queued',
                                                user_ids: job.repository.permissions.pluck(:user_id))
    service.run
  end

  describe 'sets the queue' do
    let(:config) { { language: 'objective-c', os: 'osx', osx_image: 'xcode8', group: 'stable', dist: 'osx' } }
    let(:job)    do
      FactoryBot.create(:job, state: :queued, config:, queue: nil, queued_at: Time.parse('2016-01-01T10:30:00Z'))
    end

    before { context.config.queues = [{ queue: 'builds.mac_osx', os: 'osx' }] }
    before { service.run }

    it { expect(job.reload.queue).to eq 'builds.mac_osx' }
    it { expect(log).to include "I Setting queue to builds.mac_osx for job=#{job.id}" }
  end

  # TODO: confirm we don't need queue redirection any more
  context do
    let(:queue) { 'builds.linux' }

    before { context.config[:queue_redirections] = { 'builds.linux' => 'builds.gce' } }
    before { service.run }

    it 'redirects the queue' do
      expect(job.reload.queue).to eq 'builds.gce'
    end
  end

  describe 'does not raise on encoding issues ("\xC3" from ASCII-8BIT to UTF-8)' do
    let(:config) { { global_env: ['SECURE GH_USER_NAME=Max Nöthe'.force_encoding('ASCII-8BIT')] } }
    before { job.update!(config:) }
    it { expect { service.run }.to_not raise_error }
  end
end
