require 'travis/lock'

module Travis
  module Scheduler
    module Helper
      module Locking
        def exclusive(key, config, &block)
          options = config[:lock]
          options[:url] ||= config[:redis][:url] if options[:strategy] == :redis
          debug "Locking #{key} with: #{options[:strategy]}, ttl: #{options[:ttl]}"
          Lock.exclusive(key, options, &block)
        end
      end
    end
  end
end
