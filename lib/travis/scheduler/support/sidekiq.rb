require 'sidekiq'
require 'travis/metrics/sidekiq'

module Travis
  module Scheduler
    module Support
      module Sidekiq
        class << self
          def setup(config)
            ::Sidekiq.configure_server do |c|
              c.redis = {
                url: config.redis.url,
                namespace: config.sidekiq.namespace
              }

              c.server_middleware do |chain|
                chain.add Metrics::Sidekiq
              end

              # c.logger.formatter = LogFormat.new(config.logger)
              c.logger.level = ::Logger::WARN

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
end
