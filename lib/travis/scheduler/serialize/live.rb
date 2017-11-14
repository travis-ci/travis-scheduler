module Travis
  module Scheduler
    module Serialize
      class Live < Struct.new(:job)
        def data
          {
            id:                 job.id,
            repository_id:      repo.id,
            repository_slug:    repo.slug,
            repository_private: repo.private,
            build_id:           job.source_id,
            commit_id:          job.commit_id,
            number:             job.number,
            state:              job.state.to_s,
            queue:              job.queue,
            allow_failure:      job.allow_failure,
            commit:             commit_data,
            updated_at:         format_date_with_ms(job.updated_at)
          }
        end

        private

          def commit_data
            {
              id:              commit.id,
              sha:             commit.commit,
              branch:          commit.branch,
              message:         commit.message,
              committed_at:    format_date(commit.committed_at),
              author_name:     commit.author_name,
              author_email:    commit.author_email,
              committer_name:  commit.committer_name,
              committer_email: commit.committer_email,
              compare_url:     commit.compare_url,
            }
          end

          def commit
            job.commit
          end

          def repo
            job.repository
          end

          def format_date(date)
            date && date.strftime('%Y-%m-%dT%H:%M:%SZ')
          end

          def format_date_with_ms(date)
            date && date.strftime('%Y-%m-%dT%H:%M:%S.%3NZ')
          end
      end
    end
  end
end
