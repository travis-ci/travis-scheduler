# frozen_string_literal: true

module Travis
  module Scheduler
    module Helper
      module Runner
        def async(*args)
          testing? ? inline(*args) : enqueue(*args)
        end

        def inline(service, *args)
          Service[service].new(context, *symbolize_keys(args)).run
        end

        private

        def enqueue(*args)
          Scheduler.push(*args)
        end

        def testing?
          ENV['ENV'] == 'test'
        end

        def symbolize_keys(obj)
          case obj
          when Array
            obj.map { |obj| symbolize_keys(obj) }
          when ::Hash
            obj.map { |key, value| [key.to_sym, symbolize_keys(value)] }.to_h
          else
            obj
          end
        end
      end
    end
  end
end
