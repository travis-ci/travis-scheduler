require 'travis/scheduler/helpers/deep_dup'
require 'travis/scheduler/models/job/config/addons'
require 'travis/scheduler/models/job/config/decrypt'
require 'travis/scheduler/models/job/config/normalize'

class Job
  module Config
    class << self
      include Travis::Scheduler::Helpers::DeepDup

      def decrypt(config, decryptor, options)
        config = deep_dup(config)
        config = Config::Normalize.new(config, options).apply
        config = Config::Decrypt.new(config, decryptor, options).apply
        config
      end
    end
  end
end
