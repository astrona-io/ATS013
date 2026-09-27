# Control Sidecar Injection Sandbox

Welcome to the Module 2 targeted practice sandbox. One namespace, three workloads, three different answers to "should this be in the mesh?". In this lab you'll opt the namespace in, pull one workload out, force another one in, and put every label on the one object the webhook actually reads.

## Launching the Lab
Run the following command in your terminal to boot the kind Kubernetes cluster:
```bash
astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-020/module-02/labs/lab-01
```
