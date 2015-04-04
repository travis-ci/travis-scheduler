require 'travis/support/amqp/bunny/publisher'

# This is required for travis-support AMQP bunny adapter to work
# with the latest version of bunny
module Travis
  module Amqp
    class Publisher
      class << self
        def channel
          @channel ||= Amqp.connection.create_channel
        end
      end

      def exchange
        @exchange ||= self.class.channel.exchange(name, :durable => true, :auto_delete => false, :type => type)
      end
    end
  end
end