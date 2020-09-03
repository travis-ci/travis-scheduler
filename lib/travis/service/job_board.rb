require 'faraday'
require 'json'

module Travis
  module Service
    class JobBoard < Struct.new(:job_id, :data, :config, :logger)
      PATH = '/jobs/add'

      MSGS = {
        response: 'POST to %{url} responded %{status} %{info}'
      }

      LEVEL = {
        201 => :info,
        204 => :warn
      }

      INFO = {
        201 => 'job %{id} created',
        204 => 'job %{id} already exists',
        400 => 'bad request: %{msg}',
        412 => 'site header missing',
        401 => 'auth header missing',
        403 => 'auth header invalid',
        500 => 'internal error'
      }

      def post
        puts '-----------------------'
        puts 'sb-scheduler-debugging'
        puts payload
        puts '-----------------------'
        response = http.post(PATH, JSON.dump(payload))
        log response.status
      rescue Faraday::ClientError => e
        log e.response[:status], e.response[:body]
        raise
      end

      private

        def payload
          { "@type" => "job", "id" => job_id, "data" => data }
        end

        def http
          Faraday.new(url: host, headers: headers, ssl: ssl_options) do |c|
            # c.response :logger
            c.request  :basic_auth, *auth.split(':')
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
            'Travis-Site'  => Scheduler.config.site
          }
        end

        def ssl_options
          {}
        end

        def log(status, msg = nil)
          level = LEVEL[status] || :error
          info  = (INFO[status] || '') % {
            id:  job_id,
            msg: msg
          }
          logger.send level, MSGS[:response] % {
            url:    [host, PATH].join,
            status: status,
            info:   info ? "(#{info})" : nil
          }
        end
    end
  end
end
