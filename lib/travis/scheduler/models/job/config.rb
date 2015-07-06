require 'active_support/core_ext/hash/deep_dup'
require 'travis/scheduler/models/job/config/decrypt'
require 'travis/scheduler/models/job/config/normalize'

class Job
  module Config
    def self.decrypt(config, decryptor, options)
      config = config.deep_dup
      config = Config::Normalize.new(config, options).apply
      config = Config::Decrypt.new(config, decryptor, options).apply
      config
    end
  end
end
