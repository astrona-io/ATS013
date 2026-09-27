# Upgrade And Reconfigure Istio With Helm Sandbox

Welcome to the Module 1 targeted practice sandbox. Istio 1.29.8 is installed through Helm with a non-default values file that no longer exists on disk. In this lab you'll recover that configuration, upgrade all three releases without losing any of it, make one deliberate mesh change, and finish the upgrade by restarting the data plane.

## Launching the Lab
Run the following command in your terminal to boot the kind Kubernetes cluster:
```bash
astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-030/module-01/labs/lab-01
```
