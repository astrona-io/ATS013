---
estimated_duration: 25m
---

# Migrate A Namespace From Sidecar To Ambient Mode

Istio 1.30.5 is installed with the ambient profile and the namespace sidecar-shop runs in sidecar mode. The learner swaps the labels, creates the pods again without sidecars and proves membership with ztunnel and a 200 response.

**Status: UNTESTED.** Written and statically checked only; never run on a cluster.

## Launching the Lab

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-040/module-03/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/module-03/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-040-03
```
