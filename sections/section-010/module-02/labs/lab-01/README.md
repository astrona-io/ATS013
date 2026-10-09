---
estimated_duration: 3m
---

# Install Istio With Helm

Welcome to your Helm build mission, astronaut. The cluster has no Istio. You install the three Istio charts as pinned releases in the right order, put the ingress gateway in its own namespace under its own release name, set mesh options from a values file, and prove the mesh works by bringing a running workload into it.

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
