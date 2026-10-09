# Question

Solve this question on: `terminal`

Astronaut, you have been handed a clean solar system and a platform specification. `helm` 3 and `istioctl` 1.30.5 are on your PATH, and the `istio` chart repository is registered. Two namespaces already exist, each with one running workload: `payments/checkout-api` and `legacy/batch-runner`. Neither is in the mesh, and neither namespace has a label.

Deliver the following. **Install with Helm.** The grader reads Helm's release records, and a cluster owned by both Helm and `istioctl` is a mistake, not a shortcut.

**Control plane**

1.  Istio **1.30.5**, installed as three pinned Helm releases: `istio-base` and `istiod` in `istio-system`, and the gateway in `edge`.
2.  The `istiod` release must be configured from a **values file** that sets all of:
    *   `meshConfig.accessLogFile` to `/dev/stdout`
    *   `meshConfig.outboundTrafficPolicy.mode` to `ALLOW_ANY`
    *   `pilot.autoscaleEnabled` to `false`
    *   the default sidecar resource requests: `global.proxy.resources.requests.cpu` of `10m` and `global.proxy.resources.requests.memory` of `64Mi`

**Edge**

3.  One ingress gateway, as a Helm release named **`public-gateway`**, in the **`edge`** namespace. Its Service must be of type **`NodePort`**, not `LoadBalancer`.
4.  No egress gateway anywhere in the cluster.

**Onboarding**

5.  `payments` must be **fully meshed**: `checkout-api` running with an `istio-proxy` sidecar, and that sidecar must carry the CPU and memory requests from your values file. That is the proof that the `global.proxy` block took effect and was not quietly ignored.
6.  `legacy` must stay **out of the mesh**. `batch-runner` must still be running with exactly one container, and `legacy` must carry no injection label.
7.  Leave both Deployments and the `checkout-api` Service otherwise unchanged. Do not add workloads.

**Consistency**

8.  The control plane and every proxy, the gateway included, must report the same version.

The grader reads Helm's release records, the live `istio` ConfigMap, the `public-gateway` Deployment and Service, the pods in `payments` and `legacy` with their containers and sidecar resource requests, and the image versions of `istiod`, the sidecar and the gateway.
