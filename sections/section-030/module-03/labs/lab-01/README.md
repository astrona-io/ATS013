---
estimated_duration: 3m
---

# In-Place Upgrade

Welcome to an in-place mission, astronaut. Istio 1.29.8 runs as a single mission control with the `default` profile, and the planet `inplace-demo` has three ships with communications officers on board.

Your job is to check the cluster with the target version's binary, replace mission control with 1.30.5 in the same building (no second revision), keep the profile's ingress gateway, and relaunch every ship, the gateway included, so nothing is left on the old version.

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
