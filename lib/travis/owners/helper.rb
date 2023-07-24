module Travis
  module Owners
    module Helper
      module Memoize
        module ClassMethods
          def memoize(name)
            prepend(Module.new do
              define_method(name) do |*args, &block|
                var = "@#{name.to_s.gsub(/\W/, '')}"
                return instance_variable_get(var) if instance_variable_defined?(var)

                instance_variable_set(var, super(*args, &block))
              end
            end)
          end
        end

        def self.included(base)
          base.extend(ClassMethods)
        end
      end
    end
  end
end
