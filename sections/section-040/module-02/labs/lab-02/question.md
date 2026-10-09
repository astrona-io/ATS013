# Question

Solve this question on: `terminal`

Istio 1.30.5 is installed with the **`ambient`** profile, and the **Gateway API CRDs** (Custom Resource Definitions) are installed. The namespace `ambient-l7` carries `istio.io/dataplane-mode=ambient` and runs three Deployments, all on port `80`:

- `notification-service` (nginx), behind the `notification-service` Service. The `HTTPRoute` `notification-header` attaches to this Service and sets the response header `x-processed-by: waypoint`.
- `reporting-service` (nginx), behind the `reporting-service` Service. It needs only layer 4: mutual TLS and identity from ztunnel.
- `tester` (curl), the client pod.

Right now the namespace is enrolled to a **namespace waypoint** named `waypoint`, so the traffic of **every** Service, including `reporting-service`, takes the extra hop through a waypoint. Scope layer 7 down to the one Service that needs it:

1.  Create a **service waypoint** named **`svc-waypoint`** in `ambient-l7` that handles Service traffic. Its `Gateway` must be of class `istio-waypoint`, must report `Programmed: True`, and its Deployment must be ready.
2.  Make the `notification-service` Service use `svc-waypoint`.
3.  Make sure `reporting-service` uses **no** waypoint: the namespace must no longer be enrolled to a waypoint, and the `reporting-service` Service must not point at one.
4.  Delete the namespace waypoint `waypoint`. It has no job left, and every waypoint costs resources.
5.  Prove it works with requests from `tester`:
    - `http://notification-service/` returns `200` and still carries `x-processed-by: waypoint`.
    - `http://reporting-service/` returns `200` and does **not** carry the header `server: istio-envoy`, because no Envoy is in its path.
6.  Leave the namespace in ambient mode, and leave the `HTTPRoute`, the Deployments and the Services otherwise unchanged.

The grader also reads `istioctl ztunnel-config service`: the `WAYPOINT` column must name `svc-waypoint` for `notification-service` and no waypoint for `reporting-service`.
