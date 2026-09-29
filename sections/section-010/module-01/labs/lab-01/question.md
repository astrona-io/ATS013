# Question

Solve this question on: `terminal`

The cluster is clean — there is no `istio-system` namespace, no `networking.istio.io` CRDs and no injection webhook. `istioctl` 1.30.5 is already on your PATH. Namespace `mesh-demo` exists and runs one Deployment, `notification-service`, whose pod currently has a single container.

1.  Run the pre-install check with `istioctl` and confirm the cluster has nothing in the way.
2.  Install the Istio control plane using the **`demo`** profile. When you are done, `istio-system` must hold a ready `istiod` **and both** the ingress and the egress gateway — that pairing is what distinguishes `demo` from `default`.
3.  Confirm the install created the `networking.istio.io` CRDs and the `istio-sidecar-injector` mutating webhook configuration.
4.  Enable automatic sidecar injection for the **`mesh-demo`** namespace using the label that selects the default control plane.
5.  Get the **existing** `notification-service` workload into the mesh. Labelling the namespace is not enough — the pod was admitted before the webhook applied to it, so it must be recreated. When you are finished its pod must have exactly two containers, `notification-service` and `istio-proxy`, and it must be `Ready`.
6.  Leave the `mesh-demo` Service and Deployment otherwise unchanged — do not rename them, and do not add a second Deployment.
7.  Confirm with `istioctl` that the control plane version and the data plane version match, and that the workload's proxy reports `SYNCED`.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [istioctl installation](https://istio.io/v1.30/docs/setup/install/istioctl/) — `istioctl install`, `--set`, and what the command actually applies
- [Install with Helm](https://istio.io/v1.30/docs/setup/install/helm/) — the charts, their values, and install ordering
- [Configuration profiles](https://istio.io/v1.30/docs/setup/additional-setup/config-profiles/) — what each built-in profile turns on
- [Canary upgrades](https://istio.io/v1.30/docs/setup/upgrade/canary/) — revisions, revision labels and moving workloads between control planes
- [Sidecar injection](https://istio.io/v1.30/docs/setup/additional-setup/sidecar-injection/) — the namespace label, the pod annotation, and when injection happens
- [Diagnostic tools](https://istio.io/v1.30/docs/ops/diagnostic-tools/proxy-cmd/) — `proxy-status` and `proxy-config` in full
- [istioctl command reference](https://istio.io/v1.30/docs/reference/commands/istioctl/) — every subcommand and flag
- [Installing gateways](https://istio.io/v1.30/docs/setup/additional-setup/gateway/) — deploying gateways separately from the control plane
