require 'travis/scheduler/helpers/deep_dup'
require 'travis/scheduler/models/job/config/decrypt'
require 'travis/scheduler/models/job/config/normalize'

class Job
  module Config
    class << self
      include Travis::Scheduler::Helpers::DeepDup

      def encrypted_env_removed?
        @encrypted_env_removed
      end

      def decrypt(config, decryptor, options)
        config = deep_dup(config)
        config = Config::Normalize.new(config, options).apply
        decryptor = Config::Decrypt.new(config, decryptor, options)
        config = decryptor.apply
        @encrypted_env_removed = decryptor.encrypted_env_removed?
        config
      end
    end
  end
end
