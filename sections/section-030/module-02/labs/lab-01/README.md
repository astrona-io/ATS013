---
estimated_duration: 3m
---

# Canary Upgrade With Revisions And Tags

Welcome to a canary mission, astronaut. Istio 1.29.8 runs as the single default mission control, with no revision name. The planet `canary-demo` reports to it.

Your job is to build a second mission control at 1.30.5 next to the first, give it the call sign `prod` with a revision tag, and move `canary-demo` and its one workload across through that tag, without touching the old control plane.

## Launching the Lab

Run this command to start the cluster with Istio 1.29.8 already installed:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/module-02/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-030/module-02/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-030-02
```
