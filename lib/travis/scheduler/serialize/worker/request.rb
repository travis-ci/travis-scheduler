require 'forwardable'

module Travis
  module Scheduler
    module Serialize
      class Worker
        class Request < Struct.new(:request, :config)
          extend Forwardable

          def_delegators :request, :id, :event_type, :base_commit, :head_commit, :payload

          def tag_name
            request.tag_name if request.tag_name.present?
          end

          def pull_request_head_branch
            pull_request_head['ref']
          end

          def pull_request_head_sha
            pull_request_head['sha']
          end

          def pull_request_head
            payload && payload['pull_request'] && payload['pull_request']['head'] || {}
          end
        end
      end
    end
  end
end

