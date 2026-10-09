---
estimated_duration: 20m
---

# Control Sidecar Injection

The namespace `inject-demo` holds three workloads with three different needs. The learner opts the namespace into sidecar injection, pulls one workload out of the mesh, forces another one in, and puts every label on the pod template, the one object the injection webhook actually reads.

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
