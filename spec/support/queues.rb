module Support
  module Queues
    class QueueCase
      def initialize(cutoff: NOWISH.to_s, host: 'travis-ci.org', config: {},
                     desc: 'uh???', queue: 'notset', education: false,
                     created_at: NOWISH + 7.days, force_precise_sudo_required: false,
                     force_linux_sudo_required: false)
        @cutoff = cutoff
        @host = host
        @config = config
        @desc = desc
        @queue = queue
        @education = education
        @created_at = created_at
        @force_precise_sudo_required = force_precise_sudo_required
        @force_linux_sudo_required = force_linux_sudo_required
      end

      attr_reader :created_at, :config, :cutoff, :desc, :host, :queue

      def education?
        @education
      end

      def force_precise_sudo_required?
        @force_precise_sudo_required
      end

      def force_linux_sudo_required?
        @force_linux_sudo_required
      end

      def to_s
        a = %w[when on]
        a << (host =~ /\.org/ ? 'org' : 'com')
        a << 'educational' if education?
        a << "sudo=#{config[:sudo]}" if config.key?(:sudo)
        a << "dist=#{config[:dist]}" if config.key?(:dist)
        if force_precise_sudo_required?
          a << "forced sudo required because of dist: precise"
        end
        a << "forced sudo required on linux" if force_linux_sudo_required?
        a << 'and created'
        a << (created_at < Time.parse(cutoff) ? "before" : "after")
        a << 'cutoff'
        a.join(' ')
      end
    end
  end
end
