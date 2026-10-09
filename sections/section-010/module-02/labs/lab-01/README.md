---
estimated_duration: 3m
---

# Install Istio With Helm

The cluster has no Istio. The learner installs the three Istio charts as pinned releases in the right order, puts the ingress gateway in its own namespace under its own release name, sets mesh options from a values file, and proves the mesh works by bringing a running workload into it.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-010/module-02/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/module-02/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-010-02
```
