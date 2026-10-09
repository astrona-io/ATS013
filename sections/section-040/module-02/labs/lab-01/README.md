---
estimated_duration: 25m
---

# Waypoint Proxy For L7

Welcome to your waypoint mission, astronaut. The `ambient-l7` namespace is already in the ambient mesh at layer 4: mutual TLS works, but nothing in the path can read HTTP. Your job is to add the waypoint proxy that makes layer 7 configuration possible, attach a route to the Service, and prove with a real request that something is finally reading HTTP.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-040/module-02/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/module-02/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-040-02
```
