# Question

Solve this question on: `terminal`

This lab puts both skills together: change the control plane configuration, then decide pod by pod which workloads join the mesh.

Istio 1.30.5 is installed from the **stock `demo` profile**, with no changes. `istioctl` 1.30.5 is on your path. Three workloads are running, none of them meshed, in two namespaces without injection labels:

*   `payments/checkout-api`: an nginx service that must join the mesh.
*   `payments/audit-shipper`: a log shipper in the same namespace that must **stay out**.
*   `legacy/nightly-report`: in a namespace that must stay entirely outside the mesh.

Deliver the following. Keep the installation in a reusable `IstioOperator` file.

**Control plane**

1.  The **egress gateway is removed**, and the **ingress gateway is still running**.
2.  `istiod` requests **`250m`** of CPU and **`512Mi`** of memory.
3.  Mesh-wide, Envoy access logging goes to **`/dev/stdout`**.
4.  Mesh-wide, the outbound traffic policy mode is **`REGISTRY_ONLY`**.
5.  Every injected sidecar requests **`20m`** CPU by default. This is a different layer from the control plane's own sizing: think about which key configures the *proxies* rather than `istiod`.

**Onboarding**

6.  `payments` is opted in with the label that selects the **default** control plane.
7.  `checkout-api` runs with an `istio-proxy` sidecar carrying the default request from requirement 5.
8.  `audit-shipper` runs with **exactly one container**, excluded by a `sidecar.istio.io/inject` label on its **pod template**.
9.  `legacy` carries **no mesh label of any kind** (no `istio-injection`, `istio.io/rev` or `istio.io/dataplane-mode`), and `nightly-report` runs with exactly one container.
10. All three Deployments keep their names and stay `Available`. `payments` holds exactly two Deployments, and the `checkout-api` Service stays in place. Do not add workloads.
