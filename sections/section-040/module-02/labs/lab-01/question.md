# Question

Solve this question on: `terminal`

Istio 1.30.5 is installed with the **`ambient`** profile, and the **Gateway API CRDs** are installed separately — Istio does not ship them, and a waypoint *is* a `Gateway`.

Namespace `ambient-l7` is **already enrolled** in ambient mode and runs `notification-service` (nginx) plus a `tester` pod. L4 mesh is working: ztunnel gives the workloads mutual TLS and identity. There is no waypoint and no route.

1.  Deploy a **namespace waypoint** named **`waypoint`** in `ambient-l7`, and enroll the namespace to it. Creating the proxy and pointing traffic at it are two separate things — a waypoint with nothing enrolled runs happily and receives no traffic.
2.  The waypoint's `Gateway` must be of class **`istio-waypoint`** and must report `Programmed: True`.
3.  Apply an `HTTPRoute` named **`notification-header`** in `ambient-l7` that attaches to the **`notification-service` Service** (`parentRefs` with `kind: Service`, not to a `Gateway` — this is the Gateway API's mesh pattern) and sets the response header **`x-processed-by: waypoint`**.
4.  Prove it works. A request from `tester` to `http://notification-service/` must come back carrying that header. Only something parsing HTTP can add a response header, so its presence is the proof L7 processing is in the path.
5.  Leave both Deployments and the Service unchanged, and leave the namespace enrolled in ambient mode.

If you apply the `HTTPRoute` before the waypoint exists, it will be accepted, report `Accepted`, and do nothing at all. That silent no-op is worth seeing once on purpose.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [Ambient mode overview](https://istio.io/v1.30/docs/ambient/overview/) — what ambient replaces and what it keeps
- [ztunnel architecture](https://istio.io/v1.30/docs/ambient/architecture/data-plane/) — the node proxy and what it does and does not do
- [Waypoint proxies](https://istio.io/v1.30/docs/ambient/usage/waypoint/) — where L7 policy runs in ambient
- [HBONE](https://istio.io/v1.30/docs/ambient/architecture/hbone/) — the tunnel ambient uses between nodes
- [Istio annotations and labels](https://istio.io/v1.30/docs/reference/config/annotations/) — the reference list of both
- [Diagnostic tools](https://istio.io/v1.30/docs/ops/diagnostic-tools/proxy-cmd/) — `proxy-status` and `proxy-config` in full
- [istioctl command reference](https://istio.io/v1.30/docs/reference/commands/istioctl/) — every subcommand and flag
