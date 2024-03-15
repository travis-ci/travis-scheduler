# frozen_string_literal: true

require 'faraday'
require 'json'
require 'travis/service/job_board'

module Travis
  module Scheduler
    def self.push(*args)
      ::Sidekiq::Client.push(
        'queue' => ENV['SIDEKIQ_QUEUE'] || 'scheduler',
        'class' => 'Travis::Scheduler::Worker',
        'args' => args.map! { |arg| arg.to_json },
        'at'    => args.last.is_a?(Hash) ? (args.last.delete(:at) || Time.now.to_i) : Time.now.to_i
      )
    end
  end

  module Hub
    def self.push(*args)
      ::Sidekiq::Client.push(
        'queue' => 'hub',
        'class' => 'Travis::Hub::Sidekiq::Worker',
        'args' => args.map! { |arg| arg.to_json }
      )
    end
  end

  module Live
    def self.push(*args)
      ::Sidekiq::Client.push(
        'queue' => 'pusher-live',
        'class' => 'Travis::Async::Sidekiq::Worker',
        'args' => [nil, nil, nil, *args].map! { |arg| arg.to_json }
      )
    end
  end

  module JobBoard
    class << self
      def post(job_id, data)
        Service::JobBoard.new(job_id, data, config, logger).post
      end

      def config
        Scheduler.context.config
      end

      def logger
        Scheduler.context.logger
      end
    end
  end
end
