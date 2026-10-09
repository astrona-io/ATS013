---
estimated_duration: 15m
---

# Remove Istio Completely With istioctl

The cluster runs Istio 1.30.5, installed with `istioctl` and the `demo` profile. The `mesh-demo` namespace carries the `istio-injection=enabled` label, and its two workloads, `notification-service` and `tester`, both run with an `istio-proxy` sidecar. The learner removes Istio so the cluster is fully clean: every revision and the CRDs (Custom Resource Definitions), the `istio-system` namespace, the namespace label, and the sidecars in the running pods. The grader then proves that `tester` still gets a `200` from `notification-service` without the mesh.

The grader rejects the common half-done cleanups: an uninstall without `--purge` (the CRDs stay), an uninstall with no follow-up (the namespace, the label and the sidecars stay), and deleting the workloads instead of recreating their pods.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-010/module-01/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/module-01/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-010-01-02
```
