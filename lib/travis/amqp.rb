# frozen_string_literal: true

require 'bunny'
require 'travis/amqp/publisher'

module Travis
  module Amqp
    class << self
      def setup(config, logger)
        @logger = logger

        config = config.dup
        config[:user] = config.delete(:username) if config[:username]
        config[:pass] = config.delete(:password) if config[:password]

        if config.key?(:tls)
          config[:ssl] = true
          config[:tls] = true
        end

        @config = config
        @options = {}
        @options[:spec] = config.delete(:spec) if config[:spec]

        self
      end

      attr_accessor :logger, :config, :options

      def connected?
        !!@connection
      end

      def connection
        @connection ||= Bunny.new(config, options).tap do |c|
          logger.debug 'Starting connection to RabbitMQ.'
          c.start
        end
      end
      alias connect connection

      def disconnect
        return unless connection

        logger.debug 'Closing connection to RabbitMQ.'
        connection.close if connection.open?
        @connection = nil
      end
    end
  end
end
