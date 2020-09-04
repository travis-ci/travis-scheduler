module Travis
  module Scheduler
    module Helper
      module Runner
        def async(*args)
          testing? ? inline(*args) : enqueue(*args)
        end

        # "notify", [{:job=>{:id=>380999582}, :jid=>"38aac6999227d976e5b5eb76"}]

        def inline(service, *args)
          binding.pry
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
