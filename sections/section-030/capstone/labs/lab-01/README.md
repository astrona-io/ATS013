# Section 030 Capstone: A Complete Canary Migration

This is the Section 030 integration challenge. It runs a canary upgrade end to end — stand up the new control plane, put a fleet behind a tag, migrate every namespace, and retire the old revision in the order that does not strand your workloads.

There is no step-by-step guide until you have tried it. Work from the specification.

## Launching the Lab
Run the following command in your terminal to boot the kind Kubernetes cluster:
```bash
astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-030/capstone/labs/lab-01
```
