require 'faraday_middleware'

module Travis
  module Scheduler
    module Billing
      class Client
        class Error < StandardError
          attr_reader :response

          def initialize(msg, response)
            super(msg)
            @response = response || {}
          end
        end

        DEFAULT_HEADERS  = {
          'User-Agent'     => 'Travis-CI-Scheduler/Faraday',
          'Accept'         => 'application/json',
          'Content-Type'   => 'application/json'
        }

        RETRY = {
          max: 5,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2,
          retry_statuses: [500, 502, 503, 504],
          exceptions: [
            Errno::ETIMEDOUT,
            Timeout::Error,
            Faraday::RetriableResponse,
            Faraday::TimeoutError,
            Zlib::DataError,
            Zlib::BufError,
          ]
        }

        attr_reader :context

        def initialize(context)
          @context = context
        end

        def allowance(owner_class, owner_id)
          get("/usage/#{owner_class.pluralize}/#{owner_id}/allowance")
        end

        def authorize_build(repo, owner, sender_id)
          post("/#{owner.class.name.downcase.pluralize}/#{owner.id}/authorize_build", { repository: { private: repo.private? }, sender_id: sender_id, jobs: [] })
        end

        private

        def request(method, path, params)
          client.send(method, path, params)
        rescue Faraday::ClientError => e
          puts "New-plan-error: #{e}, #{e.message}"
          puts "New-plan-error: Method: #{method}"
          puts "New-plan-error: path: #{path}"
          puts "New-plan-error: Params: #{params}"
          raise Error.new(e, e.response)
        end

        def get(path, params = {})
          request(:get, path, params).body
        end

        def post(path, params = {})
          request(:post, path, params).body
        end

        def client
          Faraday.new(url: config.billing.url, headers: DEFAULT_HEADERS) do |c|
            c.basic_auth '_', config.billing.auth_key
            c.request  :retry, RETRY
            c.request :json
            c.response :json
            c.response :raise_error
            c.adapter :net_http
          end
        end

        def config
          context.config
        end
      end
    end
  end
end
