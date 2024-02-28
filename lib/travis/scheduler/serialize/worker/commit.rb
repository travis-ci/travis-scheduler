# frozen_string_literal: true

require 'forwardable'

module Travis
  module Scheduler
    module Serialize
      class Worker
        class Commit < Struct.new(:record)
          extend Forwardable

          def_delegators :record, :id, :commit, :message, :branch, :ref, :compare_url

          def tag
            ref.to_s =~ %r{refs/tags/(.*?)$} && ::Regexp.last_match(1)
          end

          def pull_request?
            request.event_type == 'pull_request'
          end

          def range
            range = pull_request? ? pull_request_range : compare_url_range
            range.join('...') if range.any?
          end

          private

          def request
            @request ||= Request.new(record.request)
          end

          def pull_request_range
            [request.base_commit, request.head_commit]
          end

          def compare_url_range
            compare_url.to_s =~ %r{/([0-9a-f]+\^*)\.\.\.([0-9a-f]+\^*)$}
            [::Regexp.last_match(1), ::Regexp.last_match(2)].compact
          end
        end
      end
    end
  end
end
