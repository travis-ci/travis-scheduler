# frozen_string_literal: true

require 'faraday'
require 'json'

module Travis
  module Service
    class JobBoard < Struct.new(:job_id, :data, :config, :logger)
      PATH = '/jobs/add'

      MSGS = {
        response: 'POST to %<url>s responded %<status>s %<info>s'
      }.freeze

      LEVEL = {
        201 => :info,
        204 => :warn
      }.freeze

      INFO = {
        201 => 'job %<id>s created',
        204 => 'job %<id>s already exists',
        400 => 'bad request: %<msg>s',
        412 => 'site header missing',
        401 => 'auth header missing',
        403 => 'auth header invalid',
        500 => 'internal error'
      }.freeze

      def post
        response = http.post(PATH, JSON.dump(payload))
        log response.status
      rescue Faraday::ClientError => e
        log e.response[:status], e.response[:body]
        raise
      rescue Faraday::ServerError => e
        log e.response[:status], e.response[:body]
        raise
      end

      private

      def payload
        { '@type' => 'job', 'id' => job_id, 'data' => data }
      end

      def http
        Faraday.new(url: host, headers:, ssl: ssl_options) do |c|
          # c.response :logger
          c.request  :authorization, :basic, *auth.split(':')
          c.request  :retry
          c.response :raise_error
          c.adapter  :net_http
        end
      end

      def host
        config.job_board[:url]
      end

      def auth
        config.job_board[:auth]
      end

      def headers
        {
          'Content-Type' => 'application/json',
          'Travis-Site' => Scheduler.config.site
        }
      end

      def ssl_options
        {}
      end

      def log(status, msg = nil)
        level = LEVEL[status] || :error
        info  = format((INFO[status] || ''), id: job_id, msg:)
        logger.send level,
                    format(MSGS[:response], url: [host, PATH].join, status:, info: info ? "(#{info})" : nil)
      end
    end
  end
end
