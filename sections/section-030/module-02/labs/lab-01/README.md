# Canary Upgrade With Revisions And Revision Tags Sandbox

Welcome to the Module 2 targeted practice sandbox. Istio 1.29.8 runs as the single default control plane. In this lab you'll stand a second control plane up beside it, put a namespace behind a revision tag rather than a raw revision label, and move one workload across — without touching the old control plane.

## Launching the Lab
Run the following command in your terminal to boot the kind Kubernetes cluster:
```bash
astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-030/module-02/labs/lab-01
```
