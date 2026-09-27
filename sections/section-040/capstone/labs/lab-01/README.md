# Section 040 Capstone: An Ambient Mesh With Selective L7

This is the Section 040 integration challenge. It combines both modules — the ambient data plane and its restart-free enrollment, and the waypoint proxy that makes HTTP-aware behaviour possible — into one specification where the difference between what ztunnel can enforce and what needs a waypoint is the whole exercise.

There is no step-by-step guide until you have tried it. Work from the specification.

## Launching the Lab
Run the following command in your terminal to boot the kind Kubernetes cluster:
```bash
astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-040/capstone/labs/lab-01
```
