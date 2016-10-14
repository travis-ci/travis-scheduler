module Travis
  module Scheduler
    module Helper
      module Logging
        class Format < Struct.new(:msg, :context)
          def apply
            msg = []
            msg << jid[0..5]  if jid
            msg << "[#{src}]" if src
            msg << self.msg
            msg.join(' ')
          end

          private

            def jid
              context[:jid]
            end

            def src
              context[:src]
            end
        end

        %i(info warn debug error fatal).each do |level|
          define_method(level) { |msg| log(level, msg) }
        end

        def log(level, msg)
          opts = {}
          opts[:jid] = jid if respond_to?(:jid, true)
          opts[:src] = src if respond_to?(:src, true)
          logger.send(level, Format.new(msg, opts).apply)
        end
      end
    end
  end
end
