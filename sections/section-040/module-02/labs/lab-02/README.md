---
estimated_duration: 20m
---

# Scope A Waypoint To One Service

The `ambient-l7` namespace is in the ambient mesh, and one namespace waypoint named `waypoint` handles the traffic of every Service in it. Only `notification-service` needs layer 7 (its `notification-header` `HTTPRoute` sets a response header); `reporting-service` needs only layer 4. The learner replaces the namespace waypoint with a service waypoint named `svc-waypoint` for `notification-service` only, and proves with real requests from `tester` that only that Service still passes through a waypoint.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-040/module-02/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/module-02/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-040-02-02
```
