---
estimated_duration: 3m
---

# Remove An Istio Helm Install Completely

The cluster runs Istio 1.30.5, installed with Helm as three releases (`istio-base`, `istiod` and `istio-ingressgateway`), and `mesh-demo` runs one injected workload. The cluster also holds a CRD that belongs to another team. The learner removes Istio completely: uninstalls the releases, deletes only the Istio CRDs, deletes the Istio namespaces, and brings the workload back out of the mesh without replacing its Deployment.

## Launching the Lab

Run this command to start the cluster:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-010/module-02/labs/lab-02
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-010/module-02/labs/lab-02
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-010-02-02
```
