---
estimated_duration: 20m
---

# Verify A Mesh And Fix What Analyze Reports

Istio 1.30.5 is installed with the default profile. The namespace shop has pods without a sidecar and a VirtualService that points at a missing host. The learner finds both with istioctl analyze, fixes them and proves it with a clean analysis and a 200 response.

**Status: UNTESTED.** Written and statically checked only; never run on a cluster.

## Launching the Lab

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-010/module-03/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/module-03/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-010-03
```
