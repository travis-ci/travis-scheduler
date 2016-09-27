module Travis
  module Scheduler
    module With
      module ClassMethods
        def with(method, *aspects)
          prepend Module.new {
            define_method(method) do |*args, &block|
              with(*aspects) do
                super(*args, &block)
              end
            end
          }
        end
      end

      def self.included(base)
        base.extend(ClassMethods)
      end

      private

        def with(*aspects, &block)
          aspects.reverse.inject(block) do |block, aspect|
            -> { method(aspect).call(&block) }
          end.call
        end
    end
  end
end
