---
estimated_duration: 3m
---

# Control Sidecar Injection

Welcome to your mission, astronaut. One planet, `inject-demo`, holds three ships with three different needs. Your job is to opt the namespace in, pull one workload out of the mesh, force another one in, and put every label on the one object the injection webhook actually reads.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-020/module-02/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-020/module-02/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-020-02
```
