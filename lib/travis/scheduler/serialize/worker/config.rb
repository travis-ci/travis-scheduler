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
              config = Normalize.new(config, options).env_sanitize

              config
            end

            def secrets(config)
              secrets = []
              walk(config) { |obj| secrets << obj[:secure] if obj.key?(:secure) }
              secrets
            end

            def walk(obj, &block)
              case obj
              when Hash
                block.call(obj)
                obj.each { |key, obj| [key, walk(obj, &block)] }.to_h
              when Array
                obj.each { |obj| walk(obj, &block) }
              else
                obj
              end
            end
          end
        end
      end
    end
  end
end
