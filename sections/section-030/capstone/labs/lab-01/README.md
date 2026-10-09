---
estimated_duration: 3m
---

# Section 030 Capstone: A Complete Canary Migration

Welcome to your section capstone, astronaut. This mission runs a canary upgrade from start to finish: build the new mission control, give it the call sign `prod`, move every planet onto that call sign, relaunch every ship, and retire the old mission control in the order that does not strand your workloads.

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
