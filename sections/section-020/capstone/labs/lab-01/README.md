---
estimated_duration: 3m
---

# Shape The Install, Then Choose Who Joins

Welcome to the section capstone, astronaut. It combines both skills of this section into one specification: a customized control plane across all four `IstioOperator` layers, including the sidecar default that only shows up on an injected pod, and an injection decision for three workloads across two namespaces, one of which must stay entirely out of the mesh.

There is no step-by-step guide until you have tried it. Work from the specification.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-020/capstone/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-020/capstone/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-capstone-020
```
