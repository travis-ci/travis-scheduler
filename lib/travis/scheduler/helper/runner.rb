require 'travis/scheduler/worker'

module Travis
  module Scheduler
    module Runner
      def async(*args)
        testing? ? inline(*args) : enqueue(*args)
      end

      def inline(*args)
        Worker.new.perform(*args)
      end

      private

        def enqueue(*args)
          Scheduler.push(*args)
        end

        def testing?
          ENV['ENV'] == 'test'
        end

        extend self
    end
  end
end
