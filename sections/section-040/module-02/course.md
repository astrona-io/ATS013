# Add A Waypoint Proxy For L7 In Ambient Mode

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS013/tree/main/sections/section-040/module-02/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-040/module-02/playground
> astrona destroy ats-013-playground-040-02
> ```

ztunnel gives an ambient namespace mutual TLS and L4 authorization for the price of one proxy per node. What it cannot do is read HTTP — and the moment a requirement mentions a path, a method, a header, a retry or a timeout, you need something in the path that speaks HTTP.

That something is a **waypoint proxy**: an Envoy deployment you add per namespace or per service, only where L7 behaviour is actually required. The module starts by demonstrating the failure a missing waypoint produces, because it is silent and it is the one people lose an afternoon to.

## How this module is organised

1. **[Part 1 — What A Waypoint Is And How Traffic Reaches It](./course-01-what-a-waypoint-is.md)** — the silent no-op an `HTTPRoute` performs with no waypoint, the `Gateway` object behind `istioctl waypoint apply`, the field that makes it a waypoint rather than an ingress gateway, and the full path a request takes once one exists.
2. **[Part 2 — L7 Configuration Through A Waypoint](./course-02-l7-configuration-through-a-waypoint.md)** — proving L7 processing from a response, namespace versus service waypoints, what survives if the waypoint is deleted, and the operational cost of the extra hop.

## Learning objectives

After this module you can:

- Explain why an `HTTPRoute` in an ambient namespace with no waypoint is accepted and has no effect.
- Name the Kubernetes object `istioctl waypoint apply` creates and the field that makes it a waypoint.
- Describe the path a request takes from client pod to destination pod with a waypoint in place.
- Deploy a namespace waypoint, enroll workloads to it, and confirm enrollment from ztunnel's own view.
- Apply a Gateway API `HTTPRoute` through a waypoint and verify L7 processing from the response.
- Distinguish a namespace waypoint from a service waypoint, and say which behaviour survives if a waypoint is deleted.

## Before you start

You should have worked through [the ambient mode module](../module-01/course.md): you need to know what ztunnel does, what `istio.io/dataplane-mode=ambient` means, how to read `istioctl ztunnel-config workload`, and — most importantly — its Part 2 boundary between what ztunnel enforces and what it cannot.

The playground gives you a single-node `kind` cluster with **`istioctl` 1.30.5**, **Istio 1.30.5 with the `ambient` profile**, and the **Gateway API CRDs v1.5.1** installed separately — Istio does not ship them, and a waypoint *is* a `Gateway`, so without them nothing in this module works. Namespace **`ambient-l7` is already enrolled** in ambient mode and runs `notification-service` (nginx) plus a `tester` pod. L4 mesh is working; there is no waypoint and no `HTTPRoute`.

All commands run from your normal shell with `kubectl` pointed at the cluster.

## Where this fits

This module completes the ambient picture. Sidecar mode gave every workload one Envoy that did everything, L4 and L7 together, whether or not it needed the L7 half. Ambient splits that: ztunnel handles L4 for everything cheaply, and a waypoint handles L7 for the namespaces and services that ask for it.

The consequence is that L7 capability is now something you can forget to provision — which never happened in sidecar mode, because the Envoy was always there. Most ambient-mode confusion traces back to that one structural change.
