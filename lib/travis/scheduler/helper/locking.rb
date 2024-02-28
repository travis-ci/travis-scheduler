# frozen_string_literal: true

require 'travis/lock'

module Travis
  module Scheduler
    module Helper
      module Locking
        def exclusive(key, config, opts = {}, &block)
          options = config[:lock].to_h
          options = options.merge(opts)
          options[:url] ||= config[:redis][:url] if options[:strategy] == :redis
          options[:ttl] ||= 2
          info "Locking #{key} with: #{options[:strategy]}, ttl: #{options[:ttl]}s"
          options[:ttl] = options[:ttl] * 1000 # RedLock wants milliseconds
          Lock.exclusive(key, options, &block)
        end
      end
    end
  end
end
