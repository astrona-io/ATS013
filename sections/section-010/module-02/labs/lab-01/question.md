# Question

Solve this question on: `terminal`

The cluster is clean — no Istio, no CRDs, `helm ls -A` is empty. `helm` 3 and `istioctl` 1.30.5 are on your PATH and the `istio` chart repository is already added. Namespace `mesh-demo` exists and runs one Deployment, `notification-service`, whose pod currently has a single container.

Install Istio **with Helm**. Do not use `istioctl install` — the grader checks for Helm release records, and a cluster with two owners of the same objects is exactly what the module warns against.

1.  Create the namespaces `istio-system` and `edge`.
2.  Install the `istio/base` chart as a release named **`istio-base`** in `istio-system`, pinned to chart version **`1.30.5`**, with `defaultRevision` set to `default`.
3.  Install the `istio/istiod` chart as a release named **`istiod`** in `istio-system`, pinned to **`1.30.5`**, supplying its configuration from a **values file** (not only `--set` flags) that sets `meshConfig.accessLogFile` to `/dev/stdout` and disables control-plane autoscaling with `pilot.autoscaleEnabled: false`.
4.  Install the `istio/gateway` chart as a release named **`public-gateway`** in the **`edge`** namespace, pinned to **`1.30.5`**. The release name becomes the Deployment and Service name, so get it right.
5.  Do **not** install an egress gateway. There must be no egress gateway Deployment anywhere in the cluster.
6.  Enable automatic sidecar injection for `mesh-demo` and get the **existing** `notification-service` workload into the mesh, leaving its Deployment and Service otherwise unchanged.
7.  Confirm all three releases report `deployed`, that the live mesh configuration carries your access-log setting, and that the workload's proxy matches the control plane version.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [istioctl installation](https://istio.io/v1.30/docs/setup/install/istioctl/) — `istioctl install`, `--set`, and what the command actually applies
- [Install with Helm](https://istio.io/v1.30/docs/setup/install/helm/) — the charts, their values, and install ordering
- [Configuration profiles](https://istio.io/v1.30/docs/setup/additional-setup/config-profiles/) — what each built-in profile turns on
- [Canary upgrades](https://istio.io/v1.30/docs/setup/upgrade/canary/) — revisions, revision labels and moving workloads between control planes
- [Sidecar injection](https://istio.io/v1.30/docs/setup/additional-setup/sidecar-injection/) — the namespace label, the pod annotation, and when injection happens
- [ztunnel architecture](https://istio.io/v1.30/docs/ambient/architecture/data-plane/) — the node proxy and what it does and does not do
- [Istio CNI plugin](https://istio.io/v1.30/docs/setup/additional-setup/cni/) — replacing the init container's iptables work
- [Global mesh options](https://istio.io/v1.30/docs/reference/config/istio.mesh.v1alpha1/) — every mesh-wide setting and its default
- [Istio annotations and labels](https://istio.io/v1.30/docs/reference/config/annotations/) — the reference list of both
- [Diagnostic tools](https://istio.io/v1.30/docs/ops/diagnostic-tools/proxy-cmd/) — `proxy-status` and `proxy-config` in full
- [istioctl command reference](https://istio.io/v1.30/docs/reference/commands/istioctl/) — every subcommand and flag
- [Uninstalling Istio](https://istio.io/v1.30/docs/setup/install/istioctl/#uninstall-istio) — removing a control plane or one revision cleanly
- [Installing gateways](https://istio.io/v1.30/docs/setup/additional-setup/gateway/) — deploying gateways separately from the control plane
