# Question

Solve this question on: `terminal`

Istio 1.30.5 is installed with the **`ambient`** profile and the **Gateway API CRDs** are present. `istioctl` 1.30.5 is on your PATH.

Namespace `ambient-shop` is **not enrolled** and runs three workloads, each with one container:

*   `catalog-api` — an nginx service, fronted by the `catalog-api` Service.
*   `storefront` — a client.
*   `batch-runner` — another client.

Deliver the following.

**Join the mesh**

1.  Enroll `ambient-shop` in ambient mode.
2.  Do it **without recreating any pod**. The bootstrap recorded every pod's `metadata.uid` in `ambient-shop/lab-baseline`; the grader compares the live UIDs against it. Leave that ConfigMap in place.
3.  No sidecars. The namespace must carry no `istio-injection` label and every pod must still have exactly one container.

**Add L7**

4.  Deploy a **namespace waypoint** named **`waypoint`** and enroll the namespace to it. Its `Gateway` must be class `istio-waypoint` and report `Programmed: True`.
5.  Apply an `HTTPRoute` named **`catalog-header`** attaching to the **`catalog-api` Service** that sets the response header **`x-served-via: waypoint`**.

**Enforce at the right layer**

6.  Apply an `AuthorizationPolicy` named **`catalog-methods`** in `ambient-shop`, targeting the `catalog-api` workload, that **allows `GET`** and nothing else.
7.  Prove both outcomes from a client pod: a `GET` to `http://catalog-api/` returns **200**, and a `DELETE` to the same URL returns **403**.

Requirement 6 is the point of the section. A rule that matches on an HTTP method cannot be enforced by ztunnel — it is a TCP-level proxy and cannot read HTTP. Without a waypoint in the path the policy would be accepted, report healthy, and do nothing at all.

Leave all three Deployments and the Service unchanged.
