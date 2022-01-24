require 'faraday_middleware'

module Travis
  module Scheduler
    class Tam
      def initialize(user_id)
        @user_id = user_id
      end

      def get_token
        response = handle_errors_and_respond(connection.get("api/Token"))

        response['access_token']
      end

      private

        def handle_errors_and_respond(response)
          case response.status
          when 200, 201
            response.body.transform_keys { |key| key.to_s.underscore }
          when 202
            true
          when 204
            true
          when 404
            false
          when 400
          when 403
          when 422
            error :failed, response.body.fetch('errors', response.body.fetch('Errors', [])).join("\n")
          else
            error :failed, 'Artifacts API failed'
          end
        end

        def connection(timeout: 10)
          @connection ||= Faraday.new(url: artifacts_url, ssl: Travis::Scheduler.config.ssl.to_h.merge(verify: false)) do |conn|
            conn.basic_auth '_', artifacts_auth_key
            conn.headers['X-Travis-User-Id'] = @user_id.to_s
            conn.headers['Content-Type'] = 'application/json'
            conn.request :json
            conn.response :json
            conn.options[:open_timeout] = timeout
            conn.options[:timeout] = timeout
            conn.adapter :net_http
          end
        end

        def artifacts_url
          Travis::Scheduler.config.artifacts.url || raise(Error, 'No artifacts url configured')
        end

        def artifacts_auth_key
          Travis::Scheduler.config.artifacts.auth_key || raise(Error, 'No artifacts auth key configured')
        end
    end
  end
end
