module Travis
  class Queue < Struct.new(:job, :config, :logger)
    def select
      with_pool(name)
    end

    private

      def with_pool(name)
        Pool.new(job, name).to_s
      end

      def name
        queue.try(:name) || config[:queue][:default]
      end

      def queue
        queues.detect { |queue| matcher.matches?(queue.attrs) }
      end

      def matcher
        @matcher ||= Matcher.new(job, config, logger)
      end

      def queues
        @queues ||= Queues.new(config[:queues])
      end
  end
end

require 'travis/queue/matcher'
require 'travis/queue/pool'
require 'travis/queue/sudo'
require 'travis/queue/queues'
require 'travis/queue/sudo_detector'
