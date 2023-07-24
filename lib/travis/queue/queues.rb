module Travis
  class Queue
    class Queues < Struct.new(:config)
      Queue = Struct.new(:name, :attrs, :options)

      def detect(&block)
        queues.detect(&block)
      end

      private

      def queues
        Array(config).compact.map do |attrs|
          Queue.new(attrs[:queue], attrs.reject { |key, _| key == :queue })
        end
      end
    end
  end
end
