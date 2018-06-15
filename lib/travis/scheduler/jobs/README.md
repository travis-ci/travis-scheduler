Terminology:

* `running` - jobs in the state `queued`, `received`, or `started`
* `queueable` - jobs in the state `created`
* `selected` - queueable jobs that are being selected to be queued based on concurrency limits
* `waiting` - queueable jobs that can not been selected to be queued

Classes:

* `Select` is the main entry point, `run` returns accepted jobs that can be
  enqueued. `report` returns a report that can be logged.
* `Capacities` is a collection of capacity providers, like `Boost`, `Plan` etc.
* `Limits` is a collection of limits that can reject jobs from being accepted
  by the capacities.
* `State` memoizes collections of jobs and counts in order to reduce repeated
  db queries.
* `Report` generates reports.

In order to select queueable jobs for a given owner group `Select` will pass
each job (as returned by `Job.queueable`) to the `Limits`. This checks with
each limit if the job can be allowed through (e.g. this is where we reject
jobs based on a repo setting). If all limits allow the job through it will
be passed on to the `Capacities`.

Capacities provide capacity based on the repo visibility (3 free public jobs),
owner groups subscriptions, boosts, trials, educational status etc. They are
additive except for the free capacity that does not accept private jobs.

Before capacities can start accepting queueable (currently waiting) jobs they
are reduced by currently running jobs.

`Select` will stop passing jobs once capacities are exhausted.
