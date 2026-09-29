# Question

Solve this question on: `terminal`

Istio 1.30.5 is installed from the **stock `demo` profile** with no overrides. `istioctl` 1.30.5 is on your PATH. Three workloads are running, none of them meshed, in two unlabelled namespaces:

*   `payments/checkout-api` — an nginx service that must join the mesh.
*   `payments/audit-shipper` — a log shipper in the same namespace that must **stay out**.
*   `legacy/nightly-report` — in a namespace that must stay entirely outside the mesh.

Deliver the following. Keep the installation in a reusable [`IstioOperator`](https://istio.io/v1.30/docs/reference/config/istio.operator.v1alpha1/) file.

**Control plane**

1.  The **egress gateway is removed**, and the **ingress gateway is still running**.
2.  `istiod` requests **`250m`** of CPU and **`512Mi`** of memory.
3.  Mesh-wide, Envoy access logging goes to **`/dev/stdout`**.
4.  Mesh-wide, the outbound traffic policy mode is **`REGISTRY_ONLY`**.
5.  Every injected sidecar requests **`20m`** CPU by default. This is a different layer from the control plane's own sizing — think about which key configures the *proxies* rather than `istiod`.

**Onboarding**

6.  `payments` is opted in with the label that selects the **default** control plane.
7.  `checkout-api` runs with an `istio-proxy` sidecar carrying the default request from requirement 5.
8.  `audit-shipper` runs with **exactly one container**, excluded by a `sidecar.istio.io/inject` label on its **pod template**.
9.  `legacy` carries **no injection label of any kind**, and `nightly-report` runs with exactly one container.
10. All four Deployments keep their names and stay `Available`. The `checkout-api` Service stays in place. Do not add workloads.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [istioctl installation](https://istio.io/v1.30/docs/setup/install/istioctl/) — `istioctl install`, `--set`, and what the command actually applies
- [IstioOperator API](https://istio.io/v1.30/docs/reference/config/istio.operator.v1alpha1/) — every field the install API accepts
- [Install with Helm](https://istio.io/v1.30/docs/setup/install/helm/) — the charts, their values, and install ordering
- [Configuration profiles](https://istio.io/v1.30/docs/setup/additional-setup/config-profiles/) — what each built-in profile turns on
- [Canary upgrades](https://istio.io/v1.30/docs/setup/upgrade/canary/) — revisions, revision labels and moving workloads between control planes
- [Sidecar injection](https://istio.io/v1.30/docs/setup/additional-setup/sidecar-injection/) — the namespace label, the pod annotation, and when injection happens
- [Global mesh options](https://istio.io/v1.30/docs/reference/config/istio.mesh.v1alpha1/) — every mesh-wide setting and its default
- [Istio annotations and labels](https://istio.io/v1.30/docs/reference/config/annotations/) — the reference list of both
- [istioctl command reference](https://istio.io/v1.30/docs/reference/commands/istioctl/) — every subcommand and flag
- [Installing gateways](https://istio.io/v1.30/docs/setup/additional-setup/gateway/) — deploying gateways separately from the control plane
