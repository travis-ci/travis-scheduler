module Travis
  module Scheduler
    def self.push(*args)
      ::Sidekiq::Client.push(
        'queue' => ENV['SIDEKIQ_QUEUE'] || 'scheduler',
        'class' => 'Travis::Scheduler::Worker',
        'args'  => args,
        'at'    => args.last.is_a?(Hash) ? args.last.delete(:at) : nil
      )
    end
  end

  module Hub
    def self.push(*args)
      ::Sidekiq::Client.push(
        'queue' => 'hub',
        'class' => 'Travis::Hub::Sidekiq::Worker',
        'args'  => args
      )
    end
  end

  module Live
    def self.push(*args)
      ::Sidekiq::Client.push(
        'queue'   => 'pusher-live',
        'class'   => 'Travis::Async::Sidekiq::Worker',
        'args'    => [nil, nil, nil, *args]
      )
    end
  end
end
