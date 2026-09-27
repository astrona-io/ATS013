# Overview: In-Place Upgrade Of The Control Plane (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-013-playground-030-03`.
- **Two istioctl binaries**:
  - `istioctl` → **1.29.8**, the version that is installed
  - `istioctl-1.30.5` → **1.30.5**, the upgrade target
- **Istio 1.29.8 installed with the `default` profile** as the single default
  revision.
- Namespace **`inplace-demo`** with `notification-service-v1` at **two
  replicas** and a `tester` pod, all injected. Two replicas matter: during a
  rolling restart you can watch half the mesh on each version.

## Things to try

- Run `istioctl-1.30.5 x precheck` before doing anything and read every line.
  Then run it again after the upgrade and compare.
- Upgrade the control plane and then run `istioctl proxy-status` and
  `istioctl version` *before* restarting workloads. That gap is version skew,
  and seeing it is the point of the module.
- Restart only one of the two Deployments and read the mixed `proxy-status`
  output.
- `curl` from `tester` to `notification-service` throughout the upgrade and see
  whether traffic actually breaks.
- Downgrade back to 1.29.8 and count the steps. Compare that number with the
  two-command tag flip in the canary module.
- Check whether the ingress gateway restarted on its own. Gateways are
  workloads too.

## When you're done

```sh
astrona destroy ats-013-playground-030-03
```

(`astrona destroy` takes the environment name, not the config path.)
