module Travis::FilterMigratedJobs
  def filter_migrated_jobs(jobs)
    if Travis.config.com?
      jobs.find_all { |job|
        !job.org_id || (job.restarted_at && job.restarted_at > job.repository.migrated_at)
      }
    else
      jobs
    end
  end
end
