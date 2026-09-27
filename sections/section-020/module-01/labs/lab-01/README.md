# Customize An Istio Installation Sandbox

Welcome to the Module 1 targeted practice sandbox. A stock `demo` control plane is already running as your baseline. In this lab you'll write an `IstioOperator` document that deviates from it in three specific ways — one per configuration layer — and prove each change landed where that layer puts it.

## Launching the Lab
Run the following command in your terminal to boot the kind Kubernetes cluster:
```bash
astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-020/module-01/labs/lab-01
```
