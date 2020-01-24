# frozen_string_literal: true

require 'travis/remote_vcs/client'

module Travis
  class RemoteVCS
    class Repository < Client
      def meta(repository_id)
        request(:get, __method__) do |req|
          req.url "repos/#{repository_id}/meta"
        end
      end
    end
  end
end
