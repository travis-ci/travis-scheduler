
module Travis
  module Scheduler
    class VcsProxy < Struct.new(:config, :oauth_token)
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

      def initialize(config, oauth_token)
        @oauth_token = oauth_token
        @config = config
      end

      def token(repo)
        resp = get("repositories/#{repo.vcs_id}/token/get")
        resp['token'] if resp
      end

      def credentials(repo)
        get("repositories/#{repo.vcs_id}/token/get")
      end

      private

      def request(method, path, params)
        client.send(method, path, params)
      rescue Faraday::ClientError => e
        Travis.logger.error("New-plan-error: #{e}, Method: #{method}, path: #{path}, Params: #{params}")
        raise Error.new(e, e.response)
      end

      def get(path, params = {})
        request(:get, path, params).body
      end

      def post(path, params = {})
        request(:post, path, params).body
      end

      def client
        Faraday.new(url: @config.vcs_proxy_api.url, headers: DEFAULT_HEADERS) do |c|
          c.request :oauth2, @oauth_token, token_type: :bearer
          c.request  :retry, RETRY
          c.request :json
          c.response :json
          c.response :raise_error
          c.adapter :net_http
        end
      end
    end
  end
end
