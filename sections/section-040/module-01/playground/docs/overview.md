# Overview: Install Istio In Ambient Mode (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass or fail. Explore, break things, `astrona destroy`, and start over.

## What is in the box

Your training solar system holds:

- A single-node `kind` Kubernetes cluster. `kubectl` already points at it;
  the context is `kind-astro-ats-013-playground-040-01`.
- **`istioctl` 1.30.5** on your PATH.
- **Istio 1.30.5 installed with the `ambient` profile**: `istiod` plus two
  DaemonSets in `istio-system`, `istio-cni-node` and `ztunnel`. On a one-node
  `kind` cluster that means one pod of each.
- The planet (namespace) **`ambient-demo`, not yet enrolled**, running
  `notification-service` (nginx) and a `tester` pod. Both have exactly one
  container, and they keep exactly one container for the whole module.

## Things to try

- Note the pods' `AGE`, enroll the namespace, and check `AGE` again. Nothing
  restarted. That is the biggest difference from sidecar mode.
- Run `istioctl ztunnel-config workload` before and after you enroll, and
  compare the two outputs.
- Add `istio-injection=enabled` to the same namespace on top of the ambient
  label, and see what Istio does about the contradiction.
- Apply a layer 4 `AuthorizationPolicy` that denies a port, and confirm that
  ztunnel enforces it with no waypoint anywhere.
- Apply a layer 7 `AuthorizationPolicy` that matches on an HTTP method, and
  find out what happens. ztunnel cannot read the method, so watch whether
  anything is enforced at all.
- Remove the `istio.io/dataplane-mode` label and watch the workloads leave
  the mesh, again with no restart.

## When you are done

```sh
astrona destroy ats-013-playground-040-01
```

`astrona destroy` takes the environment name, not the config path.
