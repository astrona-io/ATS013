# Question

Solve this question on: `terminal`

Istio **1.29.8** is installed with the `default` profile as the single default revision: one `istiod` and one ingress gateway in `istio-system`. Namespace `inplace-demo` is meshed and runs `notification-service-v1` at **two replicas** plus a `tester` pod.

Two binaries are on your PATH: `istioctl` (1.29.8) and `istioctl-1.30.5` (the target).

Upgrade to **1.30.5 in place**:

1.  Run the pre-upgrade check with the **target version's** binary and read the output. The check asks whether *this cluster* can accept *that version*, so the old binary is the wrong tool for it.
2.  Upgrade the control plane in place, keeping the **same `default` profile** it was installed with. `istioctl install` reconciles the cluster to the document you pass — a bare `istioctl install -y` would reconcile to the default profile and discard configuration.
3.  This must be an **in-place** upgrade, not a canary. When you are done there must be exactly **one** `istiod` Deployment in `istio-system` and no revisioned control plane or revisioned webhook.
4.  The profile's ingress gateway must still be running.
5.  Close the skew window. Every proxy in the mesh — both application replicas, the `tester` pod, **and the ingress gateway** — must be running the 1.30.5 proxy image.
6.  Leave the Deployments in place. Do not delete and recreate them, and do not add any.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [istioctl installation](https://istio.io/v1.30/docs/setup/install/istioctl/) — `istioctl install`, `--set`, and what the command actually applies
- [Install with Helm](https://istio.io/v1.30/docs/setup/install/helm/) — the charts, their values, and install ordering
- [Configuration profiles](https://istio.io/v1.30/docs/setup/additional-setup/config-profiles/) — what each built-in profile turns on
- [Canary upgrades](https://istio.io/v1.30/docs/setup/upgrade/canary/) — revisions, revision labels and moving workloads between control planes
- [In-place upgrades](https://istio.io/v1.30/docs/setup/upgrade/in-place/) — when in-place is safe and what it replaces
- [Supported releases and skew](https://istio.io/v1.30/docs/releases/supported-releases/) — how far the data plane may lag the control plane
- [Diagnostic tools](https://istio.io/v1.30/docs/ops/diagnostic-tools/proxy-cmd/) — `proxy-status` and `proxy-config` in full
- [istioctl command reference](https://istio.io/v1.30/docs/reference/commands/istioctl/) — every subcommand and flag
- [Installing gateways](https://istio.io/v1.30/docs/setup/additional-setup/gateway/) — deploying gateways separately from the control plane
