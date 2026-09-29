# Question

Solve this question on: `terminal`

Istio 1.30.5 is installed from the **stock `demo` profile** with no overrides of any kind: `istiod`, an ingress gateway and an egress gateway are all running in `istio-system`. Namespace `mesh-demo` is labelled for injection and runs one meshed workload, `notification-service`. `istioctl` 1.30.5 is on your PATH.

Reconfigure the installation so all of the following are true at the same time. Keep the configuration in a reusable [`IstioOperator`](https://istio.io/v1.30/docs/reference/config/istio.operator.v1alpha1/) **file** — `--set` flags would pass the checks but leave nothing behind, which is the habit this module argues against.

1.  The **egress gateway is gone**. There must be no egress gateway Deployment in the cluster.
2.  The **ingress gateway is still running**. Removing it too would mean you reached for `minimal` instead of overriding one component of `demo`.
3.  `istiod` requests **`100m`** of CPU.
4.  Envoy access logging is written to **`/dev/stdout`**, mesh-wide.
5.  The mesh-wide outbound traffic policy mode is **`REGISTRY_ONLY`**.
6.  `mesh-demo` is still meshed and `notification-service` is still running with its sidecar.

Before you apply anything, use `istioctl` to render your file and confirm your overrides resolved the way you expect — an unmatched component name or a misplaced key is accepted silently, not rejected.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [istioctl installation](https://istio.io/v1.30/docs/setup/install/istioctl/) — `istioctl install`, `--set`, and what the command actually applies
- [IstioOperator API](https://istio.io/v1.30/docs/reference/config/istio.operator.v1alpha1/) — every field the install API accepts
- [Configuration profiles](https://istio.io/v1.30/docs/setup/additional-setup/config-profiles/) — what each built-in profile turns on
- [Global mesh options](https://istio.io/v1.30/docs/reference/config/istio.mesh.v1alpha1/) — every mesh-wide setting and its default
- [istioctl command reference](https://istio.io/v1.30/docs/reference/commands/istioctl/) — every subcommand and flag
- [Installing gateways](https://istio.io/v1.30/docs/setup/additional-setup/gateway/) — deploying gateways separately from the control plane
