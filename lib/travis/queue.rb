module Travis
  class Queue < Struct.new(:job, :config, :logger)
    def select
      queue.try(:name) || config[:queue][:default]
    end

    private

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

require 'travis/queue/sudo'
require 'travis/queue/matcher'
require 'travis/queue/queues'
require 'travis/queue/sudo_detector'

