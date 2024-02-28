# frozen_string_literal: true

module Support
  module Queues
    class QueueCase
      def initialize(host: 'travis-ci.org', config: {},
                     desc: 'uh???', queue: 'notset', education: false)
        @host = host
        @config = config
        @desc = desc
        @queue = queue
        @education = education
      end

      attr_reader :config, :desc, :host, :queue

      def education?
        @education
      end

      def to_s
        a = %w[when on]
        a << (host =~ /\.org/ ? 'org' : 'com')
        a << 'educational' if education?
        a << "sudo=#{config[:sudo]}" if config.key?(:sudo)
        a << "dist=#{config[:dist]}" if config.key?(:dist)
        a.join(' ')
      end
    end
  end
end
