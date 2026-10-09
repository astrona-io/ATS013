---
estimated_duration: 25m
---

# Waypoint Proxy For L7

The `ambient-l7` namespace is already in the ambient mesh at layer 4: ztunnel gives the workloads mutual TLS, but no component in the request path reads HTTP. The learner adds a namespace waypoint proxy, enrolls the namespace to it, attaches an `HTTPRoute` to the `notification-service` Service, and proves with a real request from `tester` that the waypoint adds the response header `x-processed-by: waypoint`.

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
