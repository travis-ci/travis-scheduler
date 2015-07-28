module Travis
  module Scheduler
    class Counter
      attr_reader :total

      def initialize
        @total = 0
        @mut = Mutex.new
      end

      def increment
        @mut.synchronize { @total += 1 }
      end

      def reset
        @mut.synchronize { @total = 0 }
      end
    end
  end
end
