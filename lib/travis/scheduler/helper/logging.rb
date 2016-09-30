module Travis
  module Scheduler
    module Helper
      module Logging
        class Format < Struct.new(:msg, :context)
          def apply
            jid ? "#{jid[0..5]} #{msg}" : msg
          end

          private

            def jid
              context[:jid]
            end
        end

        %i(info warn debug error fatal).each do |level|
          define_method(level) { |msg| log(level, msg) }
        end

        def log(level, msg)
          logger.send(level, Format.new(msg, jid: jid).apply)
        end
      end
    end
  end
end
