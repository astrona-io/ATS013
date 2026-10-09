---
estimated_duration: 15m
---

# Exclude A Port From Sidecar Traffic Capture

The namespace `inject-demo` is injected, and `notification-service` runs with an `istio-proxy` sidecar that captures every port. The learner takes outbound port `5432` out of traffic capture with the `traffic.sidecar.istio.io/excludeOutboundPorts` annotation on the pod template, keeps the workload in the mesh, and proves that the new pod's `istio-init` rules carry the exclusion.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-020/module-02/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-020/module-02/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-020-02-02
```
