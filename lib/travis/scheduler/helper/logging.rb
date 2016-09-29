module Travis
  module Scheduler
    module Logging
      %i(info warn debug error fatal).each do |level|
        define_method(level) { |msg| log(level, msg) }
      end

      def log(level, msg)
        logger.send(level, "JID=#{jid} #{msg}")
      end
    end
  end
end
