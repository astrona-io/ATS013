---
estimated_duration: 30m
---

# Upgrade And Reconfigure Istio With Helm

Istio 1.29.8 runs as three Helm releases, and `istiod` was installed with a values file that no longer exists on disk. The only record of those settings is inside the release.

The learner must recover that configuration, upgrade all three releases to 1.30.5 without losing any of it, make one change to the mesh settings on the way, and finish the upgrade by restarting the data plane so no proxy is left on the old version.

## Launching the Lab

Run this command to start the cluster with Istio 1.29.8 already installed:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/module-01/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-030/module-01/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-030-01
```
