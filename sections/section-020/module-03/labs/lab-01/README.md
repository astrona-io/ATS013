---
estimated_duration: 25m
---

# Customize The Ingress Gateway With IstioOperator

Istio 1.30.5 is installed with the default profile and a service is published through the ingress gateway. The learner writes an IstioOperator overlay that makes the gateway Service a NodePort on 30080, sets the autoscaler bounds and the resource requests, and proves it with a 200 response.

**Status: UNTESTED.** Written and statically checked only; never run on a cluster.

## Launching the Lab

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-020/module-03/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit -c sections/section-020/module-03/labs/lab-01
```

When you are done, remove the lab:

```bash
astrona destroy ats-013-lab-020-03
```
