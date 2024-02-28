# frozen_string_literal: true

require 'travis/rollout'

module Travis
  module Scheduler
    module Service
      class Event < Struct.new(:context, :event, :data)
        include Helper::With
        include Helper::Runner
        include Helper::Metrics
        include Helper::Logging
        include Helper::Locking
        include Helper::Context
        include Registry

        register :service, :event

        MSGS = {
          receive: 'Received event %s %s=%s for %s',
          ignore: 'Ignoring owner based on rollout: %s (type=%s id=%s)',
          test: 'testing exception handling in Scheduler 2.0',
          drop: 'Owner group %s is locked and already being evaluated. Dropping event %s for %s=%s.'
        }.freeze

        def run
          info format(MSGS[:receive], event, type, obj.id, repo.slug)
          Travis::Honeycomb.context.add('repo_slug', repo.slug)
          meter
          inline :enqueue_owners, attrs
        rescue Lock::Redis::LockError => e
          info format(MSGS[:drop], e.key, event, type, data[:id])
          Travis::Honeycomb.context.add('dropped', true)
        end

        private

        def rollout?(owner)
          Rollout.matches?({ uid: owner.id.to_i, owner: owner.login }, redis: Scheduler.redis)
        end

        def meter
          super(event.sub(':', '.'))
        end

        def attrs
          { owner_type: obj.owner_type, owner_id: obj.owner_id, jid: }
        end

        def obj
          @obj ||= Kernel.const_get(type.capitalize).find(data[:id])
        end

        def repo
          obj.repository
        end

        def state
          @state ||= State.new(owners, config)
        end

        def owners
          Owners.new(data, config)
        end

        def type
          event.split(':').first
        end

        def action
          event.split(':').last
        end

        def jid
          data[:jid]
        end

        def src
          data[:src]
        end
      end
    end
  end
end
