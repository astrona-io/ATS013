# Overview: Add A Waypoint Proxy For L7 In Ambient Mode (Playground)

This is a **playground**, not a lab. The environment starts clean, runs its setup script, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, run `astrona destroy`, and start over.

## What is in the box

- A single-node `kind` Kubernetes cluster. `kubectl` already points at it. The context is `kind-astro-ats-013-playground-040-02`.
- **`istioctl` 1.30.5** on your PATH: `/usr/local/bin/istioctl`, or `~/.local/bin/istioctl` if the first place was not writable.
- **Istio 1.30.5 with the `ambient` profile**: `istiod` (the control plane), `istio-cni-node` (the node agent that redirects pod traffic) and `ztunnel` (the per-node layer 4 proxy).
- **The Gateway API CRDs (Custom Resource Definitions) v1.5.1**, installed separately. Istio does not ship them, and a waypoint is a Gateway API `Gateway`, so without them `istioctl waypoint apply` fails.
- The namespace **`ambient-l7`, already enrolled** in ambient mode with the label `istio.io/dataplane-mode=ambient`. It runs the `notification-service-v1` Deployment (nginx) behind the `notification-service` Service on port `80`, and a `tester` Deployment (curl). The layer 4 mesh works; there is no waypoint and no `HTTPRoute`.

## Things to try

- Apply an `HTTPRoute` *before* you create the waypoint. It is accepted and does nothing, with no error. That is the trap this module teaches.
- Run `istioctl waypoint apply -n ambient-l7` without `--enroll-namespace`, then check `istioctl waypoint list -n ambient-l7` and `istioctl ztunnel-config service`. The waypoint runs, but no Service is routed through it.
- Delete the waypoint while you send requests from `tester`, and find out which behaviour is lost (layer 7 header changes) and which remains (mutual TLS, layer 4 policy).
- Create a service waypoint with `--for service` next to the namespace waypoint, label the `notification-service` Service `istio.io/use-waypoint=<name>`, and compare which waypoint ztunnel names for it.
- Run `kubectl -n ambient-l7 get gateway waypoint -o yaml` and find `gatewayClassName`. That one field makes the `Gateway` a waypoint instead of an ingress gateway.

## When you are done

```sh
astrona destroy ats-013-playground-040-02
```

`astrona destroy` takes the environment name, not the folder path.
