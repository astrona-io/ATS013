# Question

Solve this question on: `terminal`

Astronaut, mission control needs a newer kit, and nobody kept the order form.

Istio **1.29.8** is installed as three Helm releases: `istio-base` and `istiod` in `istio-system`, and `istio-ingressgateway` in `istio-ingress`. One workload with a sidecar, `notification-service`, runs in the `default` namespace.

`istiod` was installed with a **values file that is not the default and is no longer on disk**. Access logging is on, autoscaling of the control plane is off, and there are fixed resource requests for both the control plane and every sidecar. The only record is inside the release.

`helm` 3 is on your PATH, along with two `istioctl` binaries: `istioctl` (1.29.8, the installed version) and `istioctl-1.30.5` (the target).

Upgrade the mesh to **1.30.5**:

1.  Recover the configuration the current release was installed with, before you change anything. `helm upgrade` builds the new release from the chart plus the values you pass **on this run**. It does not carry over the values from the previous run.
2.  Upgrade **all three** releases to chart version `1.30.5`, in the correct order.
3.  Every setting from the original install must survive the upgrade: mesh-wide access logging to `/dev/stdout`, no HorizontalPodAutoscaler for the control plane, `istiod` requesting `100m` CPU and `256Mi` memory, and injected sidecars requesting `10m` CPU and `64Mi` memory.
4.  During the same upgrade, change `meshConfig.outboundTrafficPolicy.mode` from `ALLOW_ANY` to **`REGISTRY_ONLY`**.
5.  Finish the upgrade. `helm upgrade` completing is not the upgrade completing: the data plane keeps running the proxy image it was injected with. When you are done there must be **no version skew**. The control plane, the application's sidecar and the ingress gateway must all be on 1.30.5.

Leave `notification-service` in place. Do not delete and recreate the Deployment.

The grader reads the Helm release records, the `istiod` Deployment, the `istio` ConfigMap and the running pods, so every setting has to be live, not just written in a file.
