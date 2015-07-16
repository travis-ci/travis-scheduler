require 'sidekiq'

module Travis
  module Scheduler
    module Helpers
      module Live
        class Notifier < Struct.new(:job)
          def run
            Sidekiq::Client.push(
              'queue' => :'pusher-live',
              'retry' => 3,
              'class' => 'Travis::Async::Sidekiq::Worker',
              'args'  => [nil, nil, nil, payload, event: 'job:queued']
            )
          end

          private

            def payload
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
                commit: {
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
        end

        def notify_live(job)
          Notifier.new(job).run
        end
      end
    end
  end
end
