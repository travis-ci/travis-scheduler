console:   bundle exec je ./bin/console
sidekiq:   bundle exec je bin/sidekiq-pgbouncer ${SIDEKIQ_CONCURRENCY:-5} ${SIDEKIQ_QUEUE:-scheduler}
scheduler: bundle exec je bin/sidekiq-pgbouncer ${SIDEKIQ_CONCURRENCY:-5} ${SIDEKIQ_QUEUE:-scheduler}
