require 'travis/scheduler/helper/logging'
require 'travis/scheduler/helper/runner'
require 'travis/support/registry'

module Travis
  module Scheduler
    module Service
      class Event < Struct.new(:event, :data, :config)
        include Logging, Registry, Runner, Service

        register :service, :enqueue_event

        MSGS = {
          receive: 'Received event %s %s=%s for %s'
        }

        def run
          info MSGS[:receive] % [event, type, obj.id, repo.owner_name]
          inline :enqueue_owners, attrs, config
        end

        private

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
