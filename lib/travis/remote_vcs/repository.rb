# frozen_string_literal: true

require 'travis/remote_vcs/client'

module Travis
  class RemoteVCS
    class Repository < Client
      def meta(repository_id)
        key = meta_cache_key(repository_id)
        cached = redis.get(key)
        return JSON.parse(cached) if cached.present?

        data = get_meta(repository_id)
        redis.set(key, data.to_json, ex: config[:vcs][:cache_ex])
        data
      end

      private

      def meta_cache_key(repository_id)
        "vcs_repository_meta_#{repository_id}"
      end

      def get_meta(repository_id)
        request(:get, __method__) do |req|
          req.url "repos/#{repository_id}/meta"
        end
      end

      def redis
        Travis::Scheduler.context.redis
      end
    end
  end
end
