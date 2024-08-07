# frozen_string_literal: true

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

        DEFAULT_HEADERS = {
          'User-Agent' => 'Travis-CI-Scheduler/Faraday',
          'Accept' => 'application/json',
          'Content-Type' => 'application/json'
        }.freeze

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
            Zlib::BufError
          ]
        }.freeze

        attr_reader :context

        def initialize(context)
          @context = context
        end

        def allowance(owner_class, owner_id)
          get("/usage/#{owner_class.pluralize}/#{owner_id}/allowance")
        end

        def get_plan(owner)
          get("/#{owner.class.name.downcase.pluralize}/#{owner.id}/plan")
        end

        private

        def request(method, path, params)
          client.send(method, path, params)
        rescue Faraday::ClientError => e
          Travis.logger.error("New-plan-error: #{e}, Method: #{method}, path: #{path}, Params: #{params}")
          raise Error.new(e, e.response)
        end

        def get(path, params = {})
          body = request(:get, path, params).body
          return {} unless body&.length&.to_i > 0

          body.is_a?(String) ? JSON.parse(body) : body
        end

        def post(path, params = {})
          body = request(:post, path, params).body

          body&.length&.to_i > 0 && body.is_a?(String) ? JSON.parse(body) : body
        end

        def client
          Faraday.new(url: config.billing.url, headers: DEFAULT_HEADERS) do |c|
            c.request :authorization, :basic, '_', config.billing.auth_key
            c.request :retry, RETRY
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
