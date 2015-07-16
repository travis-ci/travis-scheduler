require 'sidekiq'

module Travis
  module Scheduler
    module Support
      module Sidekiq
        def self.setup(config)
          ::Sidekiq.configure_client do |c|
            c.redis = {
              url: config.redis.url,
              namespace: config.sidekiq.namespace
            }
          end
        end
      end
    end
  end
end
