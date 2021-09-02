# frozen_string_literal: true

module Travis
  module Scheduler
    module Helper
      module JobRepository
        def job_repository
          return job.repository if job.source.event_type != 'pull_request' || job.source.request.pull_request.head_repo_slug == job.source.request.pull_request.base_repo_slug

          owner_name, repo_name = job.source.request.pull_request.head_repo_slug.split('/')
          return job.repository if owner_name.nil? || owner_name.empty? || repo_name.nil? || repo_name.empty?

          ::Repository.find_by(owner_name: owner_name, name: repo_name) || job.repository
        end
      end
    end
  end
end
