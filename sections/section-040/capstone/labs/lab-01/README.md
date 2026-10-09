---
estimated_duration: 40m
---

# An Ambient Mesh With Selective L7

This is the capstone mission for the whole section, astronaut. It combines restart-free ambient enrollment with a waypoint proxy for HTTP-aware rules. The whole exercise turns on one question: which layer enforces each requirement, ztunnel at layer 4 or the waypoint at layer 7?

There is no step-by-step guide until you have tried it. Work from the specification in `question.md`.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-040/capstone/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-040/capstone/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-capstone-040
```
