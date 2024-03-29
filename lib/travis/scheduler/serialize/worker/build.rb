# frozen_string_literal: true

require 'forwardable'

module Travis
  module Scheduler
    module Serialize
      class Worker
        class Build < Struct.new(:build, :config)
          extend Forwardable

          def_delegators :build, :id, :request, :number, :event_type,
                         :pull_request_number, :sender_id

          def pull_request?
            event_type == 'pull_request'
          end

          def owner_type
            build.owner_type
          end

          def owner_id
            build.owner_id
          end

          def sender_id
            build.sender_id
          end
        end
      end
    end
  end
end
