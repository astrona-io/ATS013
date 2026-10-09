---
estimated_duration: 3m
---

# Section 030 Capstone: A Complete Canary Migration

The section capstone runs a canary upgrade from start to finish: install the new control plane revision, point the revision tag `prod` at it, move every namespace onto that tag, restart every workload, and remove the old control plane in the order that does not leave workloads without a control plane.

There is no step-by-step guide until you have tried it. Work from the task.

## Launching the Lab

Run this command to start the cluster with Istio 1.29.8 and both namespaces already in place:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/capstone/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-030/capstone/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-capstone-030
```
