# Question

Solve this question on: `terminal`

Istio 1.30.5 is installed from the **stock `demo` profile** with no overrides of any kind: `istiod`, an ingress gateway and an egress gateway are all running in `istio-system`. Namespace `mesh-demo` is labelled for injection and runs one meshed workload, `notification-service`. `istioctl` 1.30.5 is on your PATH.

Reconfigure the installation so all of the following are true at the same time. Keep the configuration in a reusable `IstioOperator` **file** — `--set` flags would pass the checks but leave nothing behind, which is the habit this module argues against.

1.  The **egress gateway is gone**. There must be no egress gateway Deployment in the cluster.
2.  The **ingress gateway is still running**. Removing it too would mean you reached for `minimal` instead of overriding one component of `demo`.
3.  `istiod` requests **`100m`** of CPU.
4.  Envoy access logging is written to **`/dev/stdout`**, mesh-wide.
5.  The mesh-wide outbound traffic policy mode is **`REGISTRY_ONLY`**.
6.  `mesh-demo` is still meshed and `notification-service` is still running with its sidecar.

Before you apply anything, use `istioctl` to render your file and confirm your overrides resolved the way you expect — an unmatched component name or a misplaced key is accepted silently, not rejected.
