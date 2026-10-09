# Question

Solve this question on: `terminal`

The cluster has no Istio control plane yet. It is clean: no Istio, no CRDs (Custom Resource Definitions), and `helm ls -A` is empty. `helm` 3 and `istioctl` 1.30.5 are on your PATH, and the `istio` chart repository is already added. The namespace `mesh-demo` exists and runs one Deployment, `notification-service`. Its pod has a single container right now.

Install Istio **with Helm**. Do not use `istioctl install`. The grader looks for Helm release records, and a cluster with two owners of the same objects is exactly what you must avoid.

1.  Create the namespaces `istio-system` and `edge`.
2.  Install the `istio/base` chart as a release named **`istio-base`** in `istio-system`, pinned to chart version **`1.30.5`**, with `defaultRevision` set to `default`.
3.  Install the `istio/istiod` chart as a release named **`istiod`** in `istio-system`, pinned to **`1.30.5`**. Supply its configuration from a **values file** (not only `--set` flags) that sets `meshConfig.accessLogFile` to `/dev/stdout` and switches off control plane autoscaling with `pilot.autoscaleEnabled: false`.
4.  Install the `istio/gateway` chart as a release named **`public-gateway`** in the **`edge`** namespace, pinned to **`1.30.5`**. The release name becomes the Deployment and Service name, so get it right.
5.  Do **not** install an egress gateway. There must be no egress gateway Deployment anywhere in the cluster.
6.  Switch on automatic sidecar injection for `mesh-demo`, and get the **existing** `notification-service` workload into the mesh. Leave its Deployment and Service otherwise unchanged.
7.  Confirm that all three releases report `deployed`, that the live mesh configuration carries your access-log setting, and that the workload's proxy matches the control plane version.

The grader reads Helm's release records, the `istiod` image version, the live `istio` ConfigMap, the Deployments in `edge` and `mesh-demo`, and the workload's pod and its proxy image.
