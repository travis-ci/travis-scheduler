# frozen_string_literal: true

module Travis
  module Scheduler
    module Helper
      module JobRepository
        def job_repository
          return job.repository if job.source.event_type != 'pull_request'

          return unless job.source.request.pull_request&.repository_id

          base_repo = ::Repository.find(job.source.request.pull_request.repository_id)

          return unless base_repo

          return job.repository if job.source.request.pull_request.head_repo_github_id == base_repo.github_id

          owner_name, repo_name = job.source.request.pull_request.head_repo_slug.split('/')
          return if owner_name.nil? || owner_name.empty? || repo_name.nil? || repo_name.empty?

          ::Repository.find_by(owner_name: owner_name, name: repo_name)
        end
      end
    end
  end
end
