---
estimated_duration: 20m
---

# Install Istio In Ambient Mode

Welcome to your first ambient mission, astronaut. The ambient data plane is installed, and no planet is enrolled yet. Your job is to bring the `ambient-demo` namespace into the mesh without recreating a single pod, and to prove it with ztunnel. The grader saved every pod's UID before you started, so it will know if anything was relaunched.

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
