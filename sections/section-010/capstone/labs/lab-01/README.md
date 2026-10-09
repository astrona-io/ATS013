---
estimated_duration: 3m
---

# Install And Onboard A Mesh

This is the integration lab for the whole section. It combines everything about installing Istio: the chart model and its order, values files, gateway release names and placement, injection timing and the three versions. You deliver one platform specification on a clean cluster.

There is no step-by-step guide until you have tried it. Work from the specification.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-010/capstone/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/capstone/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-capstone-010
```
