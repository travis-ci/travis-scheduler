# frozen_string_literal: true

require 'faraday'

module Travis
  class RemoteVCS
    class Client
      def initialize(config)
        @config = config
      end

      private

      attr_reader :config

      def connection
        @connection ||= ::Faraday.new(http_options.merge(url: config[:vcs][:url])) do |c|
          c.request :authorization, :token, config[:vcs][:token]
          c.request :retry, max: 5, interval: 0.1, backoff_factor: 2
          c.adapter :net_http
        end
      end

      def http_options
        { ssl: config[:ssl].to_h }
      end

      def request(method, name)
        resp = connection.send(method) { |req| yield(req) }
        Travis.logger.info "#{self.class.name} #{name} response status: #{resp.status}"
        if resp.success?
          resp.body.present? ? JSON.parse(resp.body) : true
        else
          raise StandardError
        end
      end
    end
  end
end
