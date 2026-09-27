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
