require 'travis/scheduler/helper/deep_dup'
require 'travis/scheduler/serialize/worker/config/addons'
require 'travis/scheduler/serialize/worker/config/decrypt'
require 'travis/scheduler/serialize/worker/config/normalize'

module Travis
  module Scheduler
    module Serialize
      class Worker
        module Config
          class << self
            include Travis::Scheduler::Helper::DeepDup

            def decrypt(config, decryptor, options)
              config = deep_dup(config)
              config = Normalize.new(config, options).apply
              config = Decrypt.new(config, decryptor, options).apply
              config = Normalize.new(config, options).jwt_sanitize
              config
            end
          end
        end
      end
    end
  end
end
