# Question

Solve this question on: `terminal`

A canary upgrade is almost finished. Two Istio control planes run in `istio-system`:

- Istio **1.29.8**, installed with the `demo` profile as the **default** revision (Deployment `istiod`, no suffix).
- Istio **1.30.5**, installed with the `minimal` profile as revision **`1-30-5`** (Deployment `istiod-1-30-5`). The revision tag **`prod`** points at it.

The namespace `canary-demo` follows the `prod` tag and runs `notification-service-v1` behind the Service `notification-service`. The team believes every workload has moved. One namespace was missed: it still uses the default control plane.

Two binaries are on your PATH: `istioctl` (1.29.8) and `istioctl-1.30.5`.

Retire the old control plane safely:

1.  Find every workload and every namespace that still depends on the default control plane.
2.  Move the namespace you found onto the new control plane **through the `prod` tag**. When you are finished, it must carry `istio.io/rev=prod` and must **not** carry `istio-injection`. No namespace in the cluster may still carry `istio-injection=enabled`.
3.  Get its workload onto the new control plane. Restart the existing Deployment; do not delete it or add a second one.
4.  Only then remove the **default** revision. `istiod-1-30-5`, the `prod` tag and the Istio CRDs (Custom Resource Definitions) must still be there when you are done.
5.  Prove that the `tester` pod still gets HTTP `200` from `http://notification-service.canary-demo`.

The grader reads the live cluster: whether the `istiod` and `istiod-1-30-5` Deployments exist, the Istio CRDs and the `prod` tag webhook, the namespace labels, the containers, proxy image, revision and readiness of the `tester` and `notification-service` pods, and the response code of a request from `tester` to `notification-service`.
