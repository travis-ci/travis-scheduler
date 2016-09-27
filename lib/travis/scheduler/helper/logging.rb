module Travis
  module Scheduler
    module Logging
      %i(info warn debug error fatal).each do |level|
        define_method(level) { |msg, *args| log(level, msg, *args) }
      end

      def log(level, msg, *args)
        logger.send(level, msg, *args)
      end

      def logger
        Scheduler.logger
      end
    end
  end
end
