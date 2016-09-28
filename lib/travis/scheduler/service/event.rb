require 'travis/rollout'
require 'travis/scheduler/helper/logging'
require 'travis/scheduler/helper/runner'
require 'travis/support/registry'

module Travis
  module Scheduler
    module Service
      class Event < Struct.new(:event, :data, :config)
        include Logging, Registry, Runner, Service

        register :service, :event

        MSGS = {
          receive: 'Received event %s %s=%s for %s',
          ignore:  'Ignoring owner based on rollout: %s (type=%s id=%s)'
        }

        def run
          if ENV['ENV'] == 'test' || rollout?(obj.owner)
            info MSGS[:receive] % [event, type, obj.id, repo.owner_name]
            inline :enqueue_owners, attrs, config
          else
            debug MSGS[:ignore] % [obj.owner.login, obj.owner_type, obj.owner.id]
          end
        end

        private

          def rollout?(owner)
            Rollout.matches?({ uid: owner.id.to_i, owner: owner.login }, redis: Scheduler.redis)
          end

          def attrs
            { owner_type: obj.owner_type, owner_id: obj.owner_id }
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
      end
    end
  end
end
