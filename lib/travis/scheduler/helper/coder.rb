require 'coder'

module Travis
  module Scheduler
    module Helper
      module Coder
        def deep_clean(obj)
          case obj
          when ::Hash, Hashr
            obj.to_h.map { |key, value| [key, deep_clean(value)] }.to_h
          when Array
            obj.map { |obj| deep_clean(obj) }
          when String
            ::Coder.clean(obj)
          else
            obj
          end
        end
      end
    end
  end
end
