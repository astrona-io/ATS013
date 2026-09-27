# Overview: Install Istio In Ambient Mode (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-013-playground-040-01`.
- **`istioctl` 1.30.5** on your PATH.
- **Istio 1.30.5 installed with the `ambient` profile**: `istiod` plus two
  DaemonSets in `istio-system`, `istio-cni-node` and `ztunnel`. On a one-node
  kind cluster that means one pod each.
- Namespace **`ambient-demo`, not yet enrolled**, running `notification-service`
  (nginx) and a `tester` pod. Both have exactly one container and will keep
  exactly one container for the whole module.

## Things to try

- Note the pods' `AGE`, enroll the namespace, and check `AGE` again. Nothing
  restarted — that is the headline difference from sidecar mode.
- Run `istioctl ztunnel-config workload` before and after enrolling and diff
  the two outputs.
- Add `istio-injection=enabled` to the same namespace on top of the ambient
  label and see what Istio does about the contradiction.
- Apply an L4 `AuthorizationPolicy` that denies a port and confirm ztunnel
  enforces it with no waypoint anywhere.
- Apply an L7 `AuthorizationPolicy` that matches on an HTTP method and find out
  what happens. (The answer is the reason the next module exists.)
- Remove the dataplane label and watch the workloads leave the mesh, again with
  no restart.

## When you're done

```sh
astrona destroy ats-013-playground-040-01
```

(`astrona destroy` takes the environment name, not the config path.)
