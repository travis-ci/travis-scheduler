module Support
  module Queues
    class QueueCase
      def initialize(host: 'travis-ci.org', config: {},
                     desc: 'uh???', queue: 'notset', education: false,
                     linux_sudo_required: false)
        @host = host
        @config = config
        @desc = desc
        @queue = queue
        @education = education
        @linux_sudo_required = linux_sudo_required
      end

      attr_reader :config, :desc, :host, :queue

      def education?
        @education
      end

      def linux_sudo_required?
        @linux_sudo_required
      end

      def to_s
        a = %w[when on]
        a << (host =~ /\.org/ ? 'org' : 'com')
        a << 'educational' if education?
        a << "sudo=#{config[:sudo]}" if config.key?(:sudo)
        a << "dist=#{config[:dist]}" if config.key?(:dist)
        a << "sudo required on linux" if linux_sudo_required?
        a.join(' ')
      end
    end
  end
end
