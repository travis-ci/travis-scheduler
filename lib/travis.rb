module Travis
  module Scheduler
    def self.push(*args)
      ::Sidekiq::Client.push(
        'queue' => 'scheduler',
        'class' => 'Travis::Scheduler::Worker',
        'args'  => args
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
