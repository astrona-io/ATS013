---
estimated_duration: 20m
---

# Retire The Old Control Plane Revision

Two Istio control planes run in the cluster: Istio 1.29.8 as the default revision, and Istio 1.30.5 as revision `1-30-5` behind the revision tag `prod`. The namespace `canary-demo` already follows the tag. The namespace `canary-legacy` was missed and still uses the default control plane.

The learner finds the namespace that was left behind, moves it onto the `prod` tag, restarts its workload, and only then removes the default revision by name, so that `istiod-1-30-5` and the shared CRDs stay and the `tester` pod still reaches `notification-service`.

## Launching the Lab

Run this command to start the cluster with both control planes already installed:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/module-02/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-030/module-02/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-030-02-02
```
