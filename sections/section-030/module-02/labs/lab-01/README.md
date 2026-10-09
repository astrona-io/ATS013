---
estimated_duration: 30m
---

# Canary Upgrade With Revisions And Tags

Istio 1.29.8 runs as the single default control plane (`istiod`), with no revision name. The namespace `canary-demo` and its one workload are injected by it.

The learner installs a second control plane at 1.30.5 as revision `1-30-5`, points the revision tag `prod` at it, and moves `canary-demo` and its workload onto it through that tag, without touching the old control plane.

## Launching the Lab

Run this command to start the cluster with Istio 1.29.8 already installed:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/module-02/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-030/module-02/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-030-02
```
