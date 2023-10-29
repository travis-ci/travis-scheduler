require 'multi_json'

module Travis
  module Amqp
    class Publisher
      class << self
        def channel
          @channel ||= Amqp.connection.create_channel.tap do
            Amqp.logger.debug "Created AMQP channel."
          end
        end
      end

      attr_reader :name, :type, :routing_key, :options

      def initialize(routing_key, options = {})
        @routing_key = routing_key
        @options = options.dup
        @name = @options.delete(:name) || ""
        @type = @options.delete(:type) || "direct"
      end

      def publish(data, options = {})
        return unless data

        Amqp.logger.warn "Queue #{routing_key} doesn't exist!" if ENV['AMQP_QUEUE_VALIDATION'] && !Amqp.connection.queue_exists?(routing_key)
        data = MultiJson.encode(data)
        exchange.publish(data, deep_merge(default_data, options))
        debug "Published AMQP message to #{routing_key}."
      rescue Exception => e
        Amqp.logger.warn "ERROR: AMQP publish for #{routing_key} exception: #{e.message}"
      end

      protected

        def default_data
          { :key => routing_key, :properties => { :message_id => rand(100000000000).to_s } }
        end

        def exchange
          @exchange ||= self.class.channel.exchange(name, :type => type.to_sym, :durable => true, :auto_delete => false)
        end

        def deep_merge(hash, other)
          hash.merge(other, &(merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }))
        end

        def debug(msg)
          Amqp.logger.debug(msg)
        end
    end
  end
end
