# frozen_string_literal: true

require 'sidekiq'
require 'travis/scheduler/helper/runner'
require 'marginalia'

module Travis
  module Scheduler
    class Worker
      include Helper::Runner
      include ::Sidekiq::Worker

      def perform(service, *args)
        service = JSON.parse(service).to_sym
        ::Marginalia.set('service', service)
        inline(service, *normalize(args))
      end

      private

      def normalize(args)
        args = args.map! { |arg| JSON.parse(arg) }
        args = symbolize_keys(args)
        args.last[:jid] ||= jid if args.last.is_a?(Hash)
        args
      end

      def context
        Scheduler.context
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
