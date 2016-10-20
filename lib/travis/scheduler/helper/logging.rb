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
          define_method(level) { |msg, *args| log(level, msg, *args) }
        end

        def log(level, msg, *args)
          opts = {}
          opts[:jid] = jid if respond_to?(:jid, true)
          opts[:src] = src if respond_to?(:src, true)
          msg = self.class::MSGS[msg] % args if msg.is_a?(Symbol)
          logger.send(level, Format.new(msg, opts).apply)
        end
      end
    end
  end
end
