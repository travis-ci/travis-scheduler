# Overview

Scheduler is a Sidekiq based application that, in the standard lifecycle of a build
request, comes third in line after Gatekeeper.

Scheduler's only purpose is to evaluate if jobs can be run based on the concurrency
limits for the given owner group.

An owner group is the group of owners that a given job belongs to. Groups can be
set up via "delegation" configuration. Most groups only contain a single owner,
which is the owner of the given job.

When a job can be run (i.e. the job's owner group is not at its concurrency limit)
then Scheduler will set the job to `queued`, and queue it for the workers.

Scheduler evaluates jobs for an owner group when a job is created (notified
from Gatekeeper), and when a job's state changes (notified from Hub).

Before publishing a job for the Workers, Scheduler also determines the RabbitMQ
queue specific to the infrastructure, based on application and job
configuration.

Scheduler also has a separate thread that periodically "pings" owner groups.
This thread publishes a single "ping" message to Sidekiq for Scheduler itself.
Scheduler will then look at all owner groups that have jobs in the `created`
state, and publish a message to itself in order to evaluate these owner groups.

The purpose of the ping is to prevent us losing messages, causing jobs to get
stuck in the `created` state.

# Resources used

Scheduler uses the following main resources:

* Redis for incoming messages (Sidekiq jobs)
* Redis for outgoing messages
* RabbitMQ for queueing messages to the workers
* the main database

It also uses:

* Sentry
* Librato
* Papertrail

## Incoming messages

* Gatekeeper for job creation
* Hub for all job state updates

## Outgoing messages

* Worker for running a job (on the RabbitMQ queues `builds.*`)

Scheduler also queues messages for itself for:

* Serializing the worker payload and publishing it to RabbitMQ.
* Periodically pinging owner groups.
* Addon notifications (sending outgoing messages)

# Incident response

## Resources

### Sidekiq dashboards

* [Sidekiq dashboard for org](https://sidekiq.travis-ci.org/)
* [Sidekiq dashboard for com](https://sidekiq.travis-ci.com/)

### Librato

* [Scheduler org space](https://metrics.librato.com/s/spaces/249400)
* [Scheduler com space](https://metrics.librato.com/s/spaces/262971)

### Heroku apps

* [Scheduler org production](https://dashboard.heroku.com/apps/travis-scheduler-production)
* [Scheduler com production](https://dashboard.heroku.com/apps/travis-pro-scheduler-prod)

### Papertrail

* [Scheduler org production](https://papertrailapp.com/systems/travis-org-scheduler-production)
* [Scheduler com production](https://papertrailapp.com/systems/travis-com-scheduler-production)

### Sentry

* [Scheduler org production](https://sentry.io/travis-ci/org-scheduler-production)
* [Scheduler com production](https://sentry.io/travis-ci/com-scheduler-production)

## Heroku cli commands

```
# check dynos
heroku ps -a travis-scheduler-production
heroku ps -a travis-pro-scheduler-prod

# scale dynos (replace N with the target dyno count)
heroku ps:scale gator=N -a travis-scheduler-production
heroku ps:scale gator=N -a travis-pro-scheduler-prod

# start a console
heroku run console -a travis-scheduler-production
heroku run console -a travis-pro-scheduler-prod
```

# Known failure modes

## Sidekiq queue backing up

Scheduler might not be able to process the amount of incoming traffic, and the
queue might back up.

There are two known conditions when this happened in the past:

* A user with massive build matrices cancelled lots of builds
* Incoming requeues from workers are drastically increased, propagating from Hub to Scheduler

The underlying condition for cancellations for huge matrices should be resolved
though, and Scheduler should be more efficient in this scenario. It is unclear
if the same scenario would happen again.

Other reasons for the queue backing up potentially might be:

* The main database is unusually slow, or queries are blocked.
* Scheduler cannot obtain connections to the main database.
* Publishing to RabbitMQ is extremely slow and all Sidekiq threads are waiting for RabbitMQ.

If Scheduler is functional (i.e. it can connect to the database, and it can
publish to RabbitMQ) then the solution to this can be to scale up more
`scheduler` dynos in order to work through the queue faster.
