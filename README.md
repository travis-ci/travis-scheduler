# Travis Scheduler [![Build Status](https://travis-ci.com/travis-ci/travis-scheduler.svg?branch=master)](https://travis-ci.com/travis-ci/travis-scheduler)

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
user sven public capacity: total=3 running=1 selected=2
user sven boost capacity: total=2 running=0 selected=2
repo sven/repo: queueable=5 running=1 selected=4 waiting=1
user sven: queueable=5 running=1 selected=4 total_waiting=1 waiting_for_concurrency=1
```

The terminology used here can be confusing. The terms mean:

* `total` - number of concurrent jobs, provided by public capacity, plan, boost, etc.
* `running` - number of jobs currently running, i.e. in the state `queued`, `received`, or `started`
* `queueable` - number of jobs in the state `created`
* `selected` - number of queueable jobs that are being selected to be queued based on concurrency limits
* `total_waiting` - total number of queueable jobs that have not been selected to be queued
* `waiting_for_concurrency` - number of queueable jobs that have not been selected, and have not been found to be limited by repo settings, queue, or stages

In the example log output above, the owner has a capacity of 3 concurrent jobs
provided by `public` capacity (line 1), and 2 jobs provided by `boost` capacity
(line 2). The job selection finds 5 jobs to be queueable (i.e. in the state
`created`), and 1 job to be running. As the total capacity is 5 jobs it can
select 4 jobs to be queued for the workers, leaving 1 job waiting.

## Contributing

See [CONTRIBUTING](CONTRIBUTING.md) for information on how to contribute to
travis-scheduler.


## License & copyright

See [MIT-LICENSE](MIT-LICENSE.md).
