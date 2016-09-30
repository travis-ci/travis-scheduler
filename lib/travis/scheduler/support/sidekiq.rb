require 'sidekiq'
require 'travis/metrics/sidekiq'

module Travis
  module Scheduler
    module Sidekiq
      class << self
        def setup(config)
          ::Sidekiq.configure_server do |c|
            c.redis = {
              url: config.redis.url,
              namespace: config.sidekiq.namespace
            }

            # Raven sets up a middleware unsolicitedly:
            # https://github.com/getsentry/raven-ruby/blob/master/lib/raven/integrations/sidekiq.rb#L28-L34
            c.error_handlers.clear

            c.server_middleware do |chain|
              chain.add Exceptions::Sidekiq, config.env, logger if config.sentry.dsn
              chain.add Metrics::Sidekiq
            end

            c.logger.level = ::Logger::const_get(config.sidekiq.log_level.upcase.to_s)

            if pro?
              c.reliable_fetch!
              c.reliable_scheduler!
            end
          end

          ::Sidekiq.configure_client do |c|
            c.redis = {
              url: config.redis.url,
              namespace: config.sidekiq.namespace
            }
          end

          if pro?
            ::Sidekiq::Client.reliable_push!
          end
        end

        def pro?
          ::Sidekiq::NAME == 'Sidekiq Pro'
        end
      end
    end
  end
end
