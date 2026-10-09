---
estimated_duration: 3m
---

# Install Istio With istioctl

Welcome to your first build mission, astronaut. The cluster has no Istio at all. You install mission control (`istiod`) with `istioctl` and the `demo` profile, confirm what the install created, bring a workload that is already running into the mesh, and prove that the control plane and the data plane run the same version.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-010/module-01/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/module-01/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-010-01
```
