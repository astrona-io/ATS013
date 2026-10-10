---
estimated_duration: 25m
---

# Customize An Istio Installation

Istio 1.30.5 already runs with the built-in `demo` profile, and the `mesh-demo` namespace runs one workload with a sidecar proxy. The learner writes an `IstioOperator` file that changes the installation in three layers at once (the egress gateway removed, `istiod` resized, two mesh-wide `meshConfig` settings turned on), and proves that each change landed where its layer puts it, without breaking the workload in the mesh.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-020/module-01/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-020/module-01/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-020-01
```
