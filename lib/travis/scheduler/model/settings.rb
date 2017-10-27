require 'settings'

# hmmm.
Settings::Definition::OWNERS[:owners] = 'Travis::Owners::Group'

module Travis
  module Scheduler
    module Model
      class Settings < ::Settings::Group
        int :by_queue,
          owner: [:owners],
          scope: :repo,
          internal: true,
          requires: :by_queue_enabled

        bool :by_queue_enabled,
          owner: [:owners],
          scope: :repo,
          internal: true
      end
    end
  end
end
