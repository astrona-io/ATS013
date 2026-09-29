# Question

Solve this question on: `terminal`

Istio **1.29.8** is installed as three Helm releases: `istio-base` and `istiod` in `istio-system`, `istio-ingressgateway` in `istio-ingress`. One injected workload, `notification-service`, runs in the `default` namespace.

`istiod` was installed with a **non-default values file that is no longer on disk**. Access logging is on, control-plane autoscaling is off, and there are explicit resource requests for both the control plane and every sidecar. The only record is inside the release.

`helm` 3 is on your PATH, along with two istioctl binaries: `istioctl` (1.29.8, the installed version) and `istioctl-1.30.5` (the target).

Upgrade the mesh to **1.30.5**:

1.  Recover the configuration the current release was installed with, before you change anything. `helm upgrade` computes the new release from the chart plus the values you pass **on this run** — values from the previous run are not carried over.
2.  Upgrade **all three** releases to chart version `1.30.5`, in the correct order.
3.  Every setting from the original install must survive the upgrade: mesh-wide access logging to `/dev/stdout`, no control-plane HorizontalPodAutoscaler, `istiod` requesting `100m` CPU and `256Mi` memory, and injected sidecars requesting `10m` CPU and `64Mi` memory.
4.  During the same upgrade, change `meshConfig.outboundTrafficPolicy.mode` from `ALLOW_ANY` to **`REGISTRY_ONLY`**.
5.  Finish the upgrade. `helm upgrade` completing is not the upgrade completing — the data plane keeps running the proxy image it was injected with. When you are done there must be **no version skew**: the control plane, the application's sidecar and the ingress gateway must all be on 1.30.5.

Leave `notification-service` in place — do not delete and recreate the Deployment.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [Install with Helm](https://istio.io/v1.30/docs/setup/install/helm/) — the charts, their values, and install ordering
- [Canary upgrades](https://istio.io/v1.30/docs/setup/upgrade/canary/) — revisions, revision labels and moving workloads between control planes
- [Supported releases and skew](https://istio.io/v1.30/docs/releases/supported-releases/) — how far the data plane may lag the control plane
- [Global mesh options](https://istio.io/v1.30/docs/reference/config/istio.mesh.v1alpha1/) — every mesh-wide setting and its default
- [istioctl command reference](https://istio.io/v1.30/docs/reference/commands/istioctl/) — every subcommand and flag
- [Installing gateways](https://istio.io/v1.30/docs/setup/additional-setup/gateway/) — deploying gateways separately from the control plane
