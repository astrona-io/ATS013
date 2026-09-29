# Question

Solve this question on: `terminal`

You have been handed a clean cluster and a platform specification. `helm` 3 and `istioctl` 1.30.5 are on your PATH and the `istio` chart repository is registered. Two namespaces already exist with one running workload each: `payments/checkout-api` and `legacy/batch-runner`. Neither is meshed and neither namespace is labelled.

Deliver the following. **Install with Helm** — the grader reads Helm's release records, and a cluster owned by both Helm and `istioctl` is a misconfiguration, not a shortcut.

**Control plane**

1.  Istio **1.30.5**, installed as three pinned Helm releases: `istio-base` and `istiod` in `istio-system`, and the gateway in `edge`.
2.  The `istiod` release must be configured from a **values file** that sets all of:
    *   `meshConfig.accessLogFile` to `/dev/stdout`
    *   `meshConfig.outboundTrafficPolicy.mode` to `ALLOW_ANY`
    *   `pilot.autoscaleEnabled` to `false`
    *   the default sidecar resource requests — `global.proxy.resources.requests.cpu` of `10m` and `global.proxy.resources.requests.memory` of `64Mi`

**Edge**

3.  One ingress gateway, as a Helm release named **`public-gateway`**, in the **`edge`** namespace. Its Service must be of type **`NodePort`**, not `LoadBalancer`.
4.  No egress gateway anywhere in the cluster.

**Onboarding**

5.  `payments` must be **fully meshed**: `checkout-api` running with an `istio-proxy` sidecar, and that sidecar must carry the CPU and memory requests from your values file — which is the proof the `global.proxy` block took effect rather than being silently ignored.
6.  `legacy` must stay **out of the mesh**. `batch-runner` must still be running with exactly one container, and `legacy` must carry no injection label.
7.  Leave both Deployments and the `checkout-api` Service otherwise unchanged. Do not add workloads.

**Consistency**

8.  The control plane and every injected proxy must report the same version.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [istioctl installation](https://istio.io/v1.30/docs/setup/install/istioctl/) — `istioctl install`, `--set`, and what the command actually applies
- [Install with Helm](https://istio.io/v1.30/docs/setup/install/helm/) — the charts, their values, and install ordering
- [Canary upgrades](https://istio.io/v1.30/docs/setup/upgrade/canary/) — revisions, revision labels and moving workloads between control planes
- [Sidecar injection](https://istio.io/v1.30/docs/setup/additional-setup/sidecar-injection/) — the namespace label, the pod annotation, and when injection happens
- [Global mesh options](https://istio.io/v1.30/docs/reference/config/istio.mesh.v1alpha1/) — every mesh-wide setting and its default
- [Istio annotations and labels](https://istio.io/v1.30/docs/reference/config/annotations/) — the reference list of both
- [istioctl command reference](https://istio.io/v1.30/docs/reference/commands/istioctl/) — every subcommand and flag
