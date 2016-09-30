module Travis
  module Scheduler
    module Helper
      module DeepDup
        def deep_dup(obj)
          case obj
          when Hash
            obj.inject({}) do |hash, (key, value)|
              hash[deep_dup(key)] = deep_dup(value)
              hash
            end
          when Array
            obj.inject([]) do |array, value|
              array << deep_dup(value)
            end
          when NilClass, TrueClass, FalseClass, Numeric, Symbol
            obj
          else
            obj.respond_to?(:dup) ? obj.dup : obj
          end
        end

        extend self
      end
    end
  end
end
