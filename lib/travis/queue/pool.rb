module Travis
  class Queue
    class Pool < Struct.new(:job, :queue)
      def self.queues
        @queues ||= Regexp.new(ENV['POOL_QUEUES'].gsub(',', '|'))
      end

      def to_s
        active? && sponsored? ? "#{queue}-#{suffix}" : queue
      end

      private

        def active?
          ENV['TRAVIS_SITE'] == 'com' && ENV['POOL_QUEUES'] && ENV['POOL_SUFFIX']
        end

        def suffix
          ENV['POOL_SUFFIX']
        end

        def sponsored?
          !job.owner.paid? && queue =~ self.class.queues
        end
    end
  end
end
