require 'active_support/concern'

module Support
  module Rollout
    def enable_rollout(name, owner)
      ENV['ENV'] = 'production'
      ENV['ROLLOUT'] = name
      context.redis.set  "#{name}.rollout.enabled", 1
      context.redis.sadd "#{name}.rollout.owners", owner.login
    end

    def disable_rollout(name, owner)
      ENV['ENV'] = 'test'
      ENV['ROLLOUT'] = nil
      context.redis.del  "#{name}.rollout.enabled"
      context.redis.del "#{name}.rollout.owners"
    end
  end
end
