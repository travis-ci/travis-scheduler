require 'forwardable'

module Travis
  module Scheduler
    module Serialize
      class Worker
        class Request < Struct.new(:request, :config)
          extend Forwardable

          def_delegators :request, :id, :event_type, :base_commit, :head_commit, :pull_request, :payload

          def pull_request_head_sha
            request.head_commit
          end

          def pull_request_head_ref
            pull_request ? pull_request.head_ref : pull_request_head['ref']
          end

          def pull_request_head_slug
            pull_request ? pull_request.head_repo_slug : pull_request_head_repo['full_name']
          end

          def pull_request_title
            pull_request ? pull_request.head_repo_title : pull_request_head_repo['title']
          end

          private

            # TODO remove once we've backfilled the pull_requests table
            def pull_request_head_repo
              pull_request_head['repo'] || {}
            end

            def pull_request_head
              payload && payload['pull_request'] && payload['pull_request']['head'] || {}
            end
        end
      end
    end
  end
end

