# Install Istio With Helm Sandbox

Welcome to the Module 2 targeted practice sandbox. In this lab you'll install the same control plane through the official Helm charts — three separate releases, in a fixed order — put the ingress gateway in its own namespace under its own release name, and prove the mesh works end to end.

## Launching the Lab
Run the following command in your terminal to boot the kind Kubernetes cluster:
```bash
astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-010/module-02/labs/lab-01
```
