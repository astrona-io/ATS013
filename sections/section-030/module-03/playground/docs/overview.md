# Overview: In-Place Upgrade Of The Control Plane (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What is in the box

- A single-node `kind` Kubernetes cluster: your training solar system.
  `kubectl` already points at it. The context is
  `kind-astro-ats-013-playground-030-03`.
- **Two `istioctl` binaries**:
  - `istioctl` is **1.29.8**, the version that is installed;
  - `istioctl-1.30.5` is **1.30.5**, the upgrade target.
- **Istio 1.29.8, installed with the `default` profile** as the only control
  plane, the default revision.
- The namespace **`inplace-demo`** with `notification-service-v1` at **two
  replicas** and a `tester` pod, all with sidecars. The two replicas matter:
  during a rolling restart you can watch half the workload on each version.

## Things to try

- Run `istioctl-1.30.5 x precheck` before you do anything and read every
  line. Run it again after the upgrade and compare.
- Upgrade the control plane, then run `istioctl proxy-status` and
  `istioctl version` *before* restarting workloads. That gap is version skew.
- Restart only one of the two Deployments and read the mixed `proxy-status`
  output.
- Send signals with `curl` from `tester` to `notification-service` during the
  whole upgrade, and see whether traffic really breaks.
- Downgrade back to 1.29.8 and count the steps. A canary rollback with a
  revision tag takes one `istioctl tag set` and a restart; compare the two.
- Check whether the ingress gateway restarted on its own. Gateways are
  workloads too.

## When you are done

```sh
astrona destroy ats-013-playground-030-03
```

`astrona destroy` takes the environment name, not the folder path.
