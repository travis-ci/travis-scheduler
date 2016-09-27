require 'forwardable'

module Travis
  module Scheduler
    module Serialize
      class Worker
        class Request < Struct.new(:request, :config)
          extend Forwardable

          def_delegators :request, :id, :event_type, :base_commit, :head_commit

          def tag_name
            request.tag_name if request.tag_name.present?
          end
        end
      end
    end
  end
end

