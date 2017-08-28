# Travis Scheduler [![Build Status](https://travis-ci.org/travis-ci/travis-scheduler.svg?branch=master)](https://travis-ci.org/travis-ci/travis-scheduler)

*Keeper of the limits*

Scheduler is the application that, in the life-cycle of accepting,
evaluating, and executing a build request, sits in the third position.

The first two positions are: Listener accepts a "request" (an incoming event
from GitHub). Gatekeeper evaluates, and configures (fetches `.travis.yml`) the
request, and creates a build record, including at least one job per build in
the database.

Now, these jobs won't start automatically. They just sit in the database, and
wait until they can be "queued" for the workers, so workers can pick them up,
and start executing them. So, "queueing" a job, in this context, means: sending
the job to the workers.

The app responsible for queueing jobs is `travis-scheduler`. The current
implementation of the scheduler looks at all jobs that are in the `created`
state (i.e. they're "waiting to be queued"), groups them by their owner
(organization, user) and evaluates how many of them can be queued. Once done
evaluating jobs for all owners it starts over.

E.g. on travis-ci.org the default concurrency limit is 5, so the scheduler will
make sure there aren't more than 5 jobs running at a time. If it finds 3 jobs
already running for a given owner, and 4 jobs waiting to be queued, it will
only queue 2 more jobs in order to respect the limit of 5.

The log output for each of these evaluation rounds looks like this:

```
one-org: total: 5, running: 8, max: 20, queueable: 5
another-org: total: 20, running: 2, max: 2, queueable: 0
```

The terminology used here can be confusing. The terms mean:

* `total` is the number of jobs waiting in the `created` state
* `running` is the number of jobs already running, so the number of jobs that
   have state `queued`, `received`, or `started`
* `max` is the concurrency limit for the given owner, i.e. the maximum number
   of jobs
* `queueable` is the result of the evaluation: how many jobs can be queued up,
   i.e. "sent to the workers", at this moment

In the example log output above, on the first line the owner `one-org` has a
concurrency limit of 20. It has 5 jobs waiting to be queued ("total"), and
already has 8 jobs running at this moment. Therefore the scheduler can queue up
5 more jobs for the workers to pick them up and execute them. (And, if someone
on this org would have pushed 12 more jobs in this moment, it could queue up
all 12 of them, too.)

On the second line the owner `another-org` has a concurrency limit of 2, 20
jobs waiting ("total"), and 2 already running. Therefore the scheduler can not
queue up any more jobs (`queueable: 0`) at this moment.

## Contributing

See the CONTRIBUTING.md file for information on how to contribute to travis-hub.
Note that we're using a [central issue tracker]
(https://github.com/travis-ci/travis-ci/issues) for all the Travis projects.


## License & copyright

See [MIT-LICENSE](MIT-LICENSE.md).
