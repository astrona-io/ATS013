# Question

Solve this question on: `terminal`

Astronaut, Istio 1.30.5 is installed with the **`ambient`** profile, and the **Gateway API CRDs** are present. `istioctl` 1.30.5 is on your PATH.

The planet (namespace) `ambient-shop` is **not enrolled** in the mesh. It runs three workloads, each with one container:

*   `catalog-api`: an nginx service, behind the `catalog-api` Service.
*   `storefront`: a client.
*   `batch-runner`: another client.

Deliver the following.

**Join the mesh**

1.  Enroll `ambient-shop` in ambient mode.
2.  Do it **without recreating any pod**. The bootstrap saved every pod's `metadata.uid` in `ambient-shop/lab-baseline`, and the grader compares the live UIDs with it. Leave that ConfigMap in place.
3.  No sidecars. The namespace must carry no `istio-injection` label, and every pod must still have exactly one container.

**Add layer 7**

4.  Deploy a **namespace waypoint** named **`waypoint`** and enroll the namespace to it. Its `Gateway` must be class `istio-waypoint` and report `Programmed: True`, and its Deployment must be ready. ztunnel must route the `catalog-api` Service through it (the `WAYPOINT` column of `istioctl ztunnel-config service`).
5.  Apply an `HTTPRoute` named **`catalog-header`** that attaches to the **`catalog-api` Service** and sets the response header **`x-served-via: waypoint`**.

**Enforce at the right layer**

6.  Apply an `AuthorizationPolicy` named **`catalog-methods`** in `ambient-shop`, for `catalog-api`, that **allows `GET`** and nothing else.
7.  Prove both outcomes from the `storefront` pod (the grader sends its requests from there): a `GET` to `http://catalog-api/` returns **200** and carries the `x-served-via: waypoint` header, and a `DELETE` to the same URL returns **403**.

Requirement 6 is the point of this capstone. ztunnel cannot enforce a rule that matches on an HTTP method: it works at layer 4 and cannot read HTTP. Without a waypoint in the path, the policy would be accepted, report healthy, and do nothing at all.

Leave all three Deployments and the Service unchanged.
