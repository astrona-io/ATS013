# Question

Solve this question on: `terminal`

Astronaut, Istio 1.30.5 is installed with the **`ambient`** profile, and the **Gateway API CRDs** are installed separately. Istio does not ship them, and a waypoint *is* a `Gateway`.

The planet (namespace) `ambient-l7` is **already enrolled** in ambient mode. It runs `notification-service` (nginx) and a `tester` pod. The layer 4 mesh works: ztunnel gives the workloads mutual TLS and identity. But ztunnel cannot read HTTP. There is no waypoint and no route.

1.  Deploy a **namespace waypoint** named **`waypoint`** in `ambient-l7`, and enroll the namespace to it. Creating the proxy and sending traffic to it are two separate things: a waypoint with nothing enrolled runs happily and receives no traffic.
2.  The waypoint's `Gateway` must be of class **`istio-waypoint`**, must report `Programmed: True`, and its Deployment must be ready.
3.  Apply an `HTTPRoute` named **`notification-header`** in `ambient-l7`. It must attach to the **`notification-service` Service** (`parentRefs` with `kind: Service`, not a `Gateway`; this is the Gateway API's mesh pattern), report `Accepted`, and set the response header **`x-processed-by: waypoint`**.
4.  Prove it works. A request from `tester` to `http://notification-service/` must return `200` and carry that header. Only something that reads HTTP can add a response header, so the header proves layer 7 processing is in the path.
5.  Leave both Deployments and the Service unchanged, and leave the namespace enrolled in ambient mode.

The grader also checks that ztunnel routes the `notification-service` Service through the waypoint: the `WAYPOINT` column of `istioctl ztunnel-config service` must name `waypoint`.

If you apply the `HTTPRoute` before the waypoint exists, it is accepted, reports `Accepted`, and does nothing at all. That silent no-op is worth seeing once on purpose.
