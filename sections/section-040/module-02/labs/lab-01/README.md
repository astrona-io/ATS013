# Add A Waypoint Proxy For L7 In Ambient Mode Sandbox

Welcome to the Module 2 targeted practice sandbox. The namespace is already in the ambient mesh at L4 — mutual TLS works, and HTTP is invisible to it. In this lab you'll add the waypoint proxy that makes L7 configuration possible, then prove with a real request that something is finally parsing HTTP.

## Launching the Lab
Run the following command in your terminal to boot the kind Kubernetes cluster:
```bash
astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-040/module-02/labs/lab-01
```
