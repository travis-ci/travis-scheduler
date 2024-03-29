# frozen_string_literal: true

module Travis::FilterMigratedJobs
  def filter_migrated_jobs(jobs)
    if Travis.config.com?
      jobs.find_all do |job|
        !job.org_id || (job.restarted_at && job.restarted_at > job.repository.migrated_at)
      end
    else
      jobs
    end
  end
end
