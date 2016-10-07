require 'travis/scheduler/model/delegates'
require 'travis/scheduler/model/subscriptions'

module Travis
  module Scheduler
    module Model
      class Owners < Struct.new(:attrs, :config)
        def all
          @all ||= delegates.push(owner).uniq.compact.sort_by(&:login)
        end

        def key
          logins.join(':')
        end

        def logins
          all.map(&:login)
        end

        def max_jobs
          subscriptions.max_jobs
        end

        def subscribed_owners
          subscriptions.subscribers
        end

        def ==(other)
          key == other.key
        end

        def to_s
          all.map { |owner| [owner.is_a?(User) ? 'user' : 'org', owner.login].join(' ') }.join(', ')
        end

        private

          def subscriptions
            @subscriptions ||= Subscriptions.new(self, config[:plans])
          end

          def owner
            @owner ||= Kernel.const_get(owner_type).find(owner_id)
          end

          def owner_type
            attrs[:owner_type] || fail("owner_type not given: #{attrs}")
          end

          def owner_id
            attrs[:owner_id] || fail("owner_id not given: #{attrs}")
          end

          def delegates
            Delegates.new(owner.login, config.to_h).all
          end
      end
    end
  end
end
