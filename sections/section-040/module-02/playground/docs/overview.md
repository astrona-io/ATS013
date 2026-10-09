# Overview: Add A Waypoint Proxy For L7 In Ambient Mode (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass or fail. Explore, break things, `astrona destroy`, and start over.

## What is in the box

Your training solar system holds:

- A single-node `kind` Kubernetes cluster. `kubectl` already points at it;
  the context is `kind-astro-ats-013-playground-040-02`.
- **`istioctl` 1.30.5** on your PATH.
- **Istio 1.30.5 with the `ambient` profile** (`istiod`, `istio-cni-node`,
  `ztunnel`).
- **The Gateway API CRDs v1.5.1**, installed separately. Istio does not ship
  them, and a waypoint is a `Gateway`, so without them
  `istioctl waypoint apply` fails.
- The planet (namespace) **`ambient-l7`, already enrolled** in ambient mode,
  running `notification-service` (nginx) and a `tester` pod. The layer 4 mesh
  works; there is no waypoint and no `HTTPRoute`.

## Things to try

- Apply an `HTTPRoute` *before* you create the waypoint. It is accepted and
  does nothing. That silent no-op is the trap this module teaches.
- Run `istioctl waypoint apply` without `--enroll-namespace`, then check
  `istioctl waypoint list` and `istioctl ztunnel-config service`. The
  waypoint runs, but no Service is routed through it.
- Delete the waypoint while traffic is flowing, and find out which behaviour
  is lost (layer 7 header changes) and which survives (mutual TLS, layer 4
  policy).
- Create a service waypoint with `--for service` next to the namespace one,
  and compare which Services each one serves.
- Read `kubectl -n ambient-l7 get gateway waypoint -o yaml` and find
  `gatewayClassName`. That one field makes it a waypoint instead of an
  ingress gateway.

## When you are done

```sh
astrona destroy ats-013-playground-040-02
```

`astrona destroy` takes the environment name, not the config path.
