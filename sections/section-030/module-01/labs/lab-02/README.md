---
estimated_duration: 20m
---

# Roll Back A Helm Release Of istiod

Istio 1.29.8 runs as three Helm releases. Someone ran `helm upgrade` on the `istiod` release with `--reset-values` and no values file, so revision 2 reset every setting from the install to the chart defaults, and the workload was restarted afterwards. The learner rolls `istiod` back to revision 1 with `helm rollback`, proves that the original settings are live again, and restarts the workload so its sidecar proxy gets the original resource requests back.

## Launching the Lab

Run this command to start the cluster with the bad upgrade already applied:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/module-01/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-030/module-01/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-030-01-02
```
