---
estimated_duration: 3m
---

# Customize An Istio Installation

Welcome to your mission, astronaut. Mission control is already running on the stock `demo` blueprint. Your job is to write an `IstioOperator` file that changes it in three layers at once (one gateway removed, `istiod` resized, two mesh-wide settings switched on) and to prove each change landed where its layer puts it, without breaking the workload already in the mesh.

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
