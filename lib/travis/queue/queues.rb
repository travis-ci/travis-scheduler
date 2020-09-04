module Travis
  class Queue
    class Queues < Struct.new(:config)
      Queue = Struct.new(:name, :attrs, :options)

      def detect(&block)
        queues.detect(&block)
      end

      private

        def queues
          puts "config debugging is: #{Array(config)}"
          Array(config).compact.map do |attrs|
            puts "Queue name is: #{attrs[:queue]}, Queue attrs #{attrs}"
            puts "Queue debugging is: #{Queue.new(attrs[:queue], attrs.reject { |key, _| key == :queue })}"
            Queue.new(attrs[:queue], attrs.reject { |key, _| key == :queue })
          end
        end
    end
  end
end
