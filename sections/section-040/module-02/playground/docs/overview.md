# Overview: Add A Waypoint Proxy For L7 In Ambient Mode (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-013-playground-040-02`.
- **`istioctl` 1.30.5** on your PATH.
- **Istio 1.30.5 with the `ambient` profile** (`istiod`, `istio-cni-node`,
  `ztunnel`).
- **The Gateway API CRDs v1.5.1**, installed separately. Istio does not ship
  them, and a waypoint is a `Gateway`, so without them
  `istioctl waypoint apply` fails.
- Namespace **`ambient-l7`, already enrolled** in ambient mode, running
  `notification-service` (nginx) and a `tester` pod. L4 mesh is working; there
  is no waypoint and no `HTTPRoute`.

## Things to try

- Apply an `HTTPRoute` *before* creating the waypoint. It will be accepted and
  do nothing. That silent no-op is the trap this module exists to teach.
- Run `istioctl waypoint apply` without `--enroll-namespace`, check
  `istioctl waypoint list`, and see the enrolled-workload count stay at zero.
- Delete the waypoint while traffic is flowing and find out which behaviour is
  lost (L7 header rewriting) and which survives (mTLS, L4 policy).
- Create a service-scoped waypoint with `--for service` alongside the
  namespace one and compare what each claims.
- Read `kubectl -n ambient-l7 get gateway waypoint -o yaml` and find
  `gatewayClassName`. That single field is what makes it a waypoint rather than
  an ingress gateway.

## When you're done

```sh
astrona destroy ats-013-playground-040-02
```

(`astrona destroy` takes the environment name, not the config path.)
