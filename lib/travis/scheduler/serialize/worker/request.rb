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

          def pull_request_base_slug
            pull_request ? pull_request.base_repo_slug : pull_request_base_repo['full_name']
          end

          def pull_request_base_ref
            pull_request ? pull_request.base_ref : pull_request_head['base_ref']
          end

          def pull_request_head_url(repo)
            pull_request.head_url(repo) if pull_request
          end

          def pull_request_is_draft?
            pull_request.mergeable_state == 'draft' if pull_request
          end

          private

            # TODO remove once we've backfilled the pull_requests table
            def pull_request_head_repo
              pull_request_head['repo'] || {}
            end

            def pull_request_base_repo
              pull_request_head['base'] || {}
            end

            def pull_request_head
              payload && payload['pull_request'] && payload['pull_request']['head'] || {}
            end

            def pull_request_base
              payload && payload['pull_request'] && payload['pull_request']['base'] || {}
            end
        end
      end
    end
  end
end

