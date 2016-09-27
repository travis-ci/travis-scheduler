require 'gh'
require 'core_ext/hash/compact'

module Travis
  module Scheduler
    module Github
      class << self
        def setup
          GH.set(
            client_id:      Travis.config.oauth2.client_id,
            client_secret:  Travis.config.oauth2.client_secret,
            user_agent:     "Travis-CI/Travis-Scheduler GH/#{GH::VERSION}",
            origin:         Travis.config.host,
            api_url:        Travis.config.github.api_url,
            ssl:            Travis.config.ssl.to_h.merge(Travis.config.github.ssl || {}).to_h.compact
          )
        end
      end
    end
  end
end
