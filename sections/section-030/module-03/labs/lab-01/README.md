# In-Place Upgrade Of The Control Plane Sandbox

Welcome to the Module 3 targeted practice sandbox. One control plane at 1.29.8, two application replicas and a gateway all running its proxies. In this lab you'll pre-check the cluster with the target binary, replace the control plane in place, and then close the version-skew window that opens the moment you do.

## Launching the Lab
Run the following command in your terminal to boot the kind Kubernetes cluster:
```bash
astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-030/module-03/labs/lab-01
```
