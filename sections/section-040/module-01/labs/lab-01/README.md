---
estimated_duration: 20m
---

# Install Istio In Ambient Mode

Istio 1.30.5 is installed with the `ambient` profile, and no namespace is in the mesh yet. The learner adds the `ambient-demo` namespace to the ambient mesh without creating any pod again, and proves it with `istioctl ztunnel-config workload`. The bootstrap saves every pod's UID before the learner starts, so the grader can tell if any pod was replaced.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-040/module-01/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/module-01/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-040-01
```
