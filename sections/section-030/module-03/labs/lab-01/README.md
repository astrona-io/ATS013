---
estimated_duration: 3m
---

# In-Place Upgrade

Istio 1.29.8 runs as a single control plane (`istiod`) with the `default` profile. The namespace `inplace-demo` runs `notification-service-v1` at two replicas and a `tester` pod, all with sidecar proxies.

The learner checks the cluster with the target version's `istioctl` binary, upgrades the control plane to 1.30.5 in place (no second revision), keeps the profile's ingress gateway, and restarts every workload, the gateway included, so no proxy is left on the old version.

## Launching the Lab

Run this command to start the cluster with Istio 1.29.8 already installed:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/module-03/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-030/module-03/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-030-03
```
