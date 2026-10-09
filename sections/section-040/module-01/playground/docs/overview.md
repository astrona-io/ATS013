# Overview: Install Istio In Ambient Mode (Playground)

This is a **playground**, not a lab. The environment starts clean, runs `bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, run `astrona destroy`, and start over.

## What is in the box

- A single-node `kind` Kubernetes cluster. `kubectl` already points at it. The context is `kind-astro-ats-013-playground-040-01`.
- **`istioctl` 1.30.5** on your PATH.
- **Istio 1.30.5 installed with the `ambient` profile**: `istiod` (the Istio control plane) plus two DaemonSets in `istio-system`, `istio-cni-node` and `ztunnel`. A DaemonSet runs one pod on every node, so on a one-node `kind` cluster there is one pod of each. `istio-cni-node` redirects the traffic of pods in the mesh, and `ztunnel` is the shared layer 4 proxy that carries it.
- The namespace **`ambient-demo`, not yet part of the mesh**, running `notification-service` (nginx, Deployment `notification-service-v1`) and a `tester` pod with `curl`. Both pods have exactly one container, and they keep exactly one container even after they join the mesh.

## Things to try

- Note the pods' `AGE`, add the label `istio.io/dataplane-mode=ambient` to the namespace, and check `AGE` again. No pod restarted. That is the biggest difference from sidecar mode.
- Run `istioctl ztunnel-config workload` before and after you add the label, and compare the `PROTOCOL` column of the two outputs.
- Add `istio-injection=enabled` to the same namespace on top of the ambient label, and see what Istio does about the contradiction.
- Apply a layer 4 `AuthorizationPolicy` that denies a port, and confirm that ztunnel enforces it with no waypoint proxy anywhere.
- Apply a layer 7 `AuthorizationPolicy` that matches on an HTTP method, and find out what happens. ztunnel cannot read the method, so check whether anything is enforced at all.
- Remove the `istio.io/dataplane-mode` label and watch the workloads leave the mesh, again with no restart.

## When you are done

```sh
astrona destroy ats-013-playground-040-01
```

`astrona destroy` takes the environment name, not the folder path.
