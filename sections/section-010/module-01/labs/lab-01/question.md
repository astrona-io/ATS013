# Question

Solve this question on: `terminal`

The cluster has no Istio control plane yet. It is clean: there is no `istio-system` namespace, no `networking.istio.io` CRDs (Custom Resource Definitions) and no injection webhook. `istioctl` 1.30.5 is already on your PATH. The namespace `mesh-demo` exists and runs one Deployment, `notification-service`. Its pod has a single container right now.

Do the following:

1.  Run the pre-install check with `istioctl` and confirm that nothing in the cluster is in the way.
2.  Install the Istio control plane with the **`demo`** profile. When you are done, `istio-system` must hold a ready `istiod` **and both** the ingress and the egress gateway. Having both gateways is what tells `demo` apart from `default`.
3.  Confirm that the install created the `networking.istio.io` CRDs and the `istio-sidecar-injector` mutating webhook configuration.
4.  Switch on automatic sidecar injection for the **`mesh-demo`** namespace, using the label that selects the default control plane.
5.  Get the **existing** `notification-service` workload into the mesh. Labelling the namespace is not enough: the pod was created before the webhook applied to it, so it must be created again. When you are finished, its pod must run both the `notification-service` and the `istio-proxy` containers, and it must be `Ready`.
6.  Leave the `mesh-demo` Service and Deployment otherwise unchanged. Do not rename them, and do not add a second Deployment.
7.  Confirm with `istioctl` that the control plane version and the data plane version match, and that the workload's proxy reports `SYNCED`.

The grader reads the live cluster: the Deployments in `istio-system`, the CRDs and the webhook, the namespace label, the workload's pod and its containers, and the image versions of `istiod` and the injected proxy.
