# Question

Solve this question on: `terminal`

The cluster runs Istio 1.30.5, installed with Helm. There are three releases: `istio-base` and `istiod` in `istio-system`, and `istio-ingressgateway` in `istio-ingress`. `helm` 3 and `istioctl` 1.30.5 are on your PATH. The namespace `mesh-demo` carries the label `istio-injection=enabled` and runs one Deployment, `notification-service`. Its pod runs the `notification-service` container and an `istio-proxy` sidecar.

The cluster also holds the CRD (Custom Resource Definition) `backups.platform.example.com`. It belongs to another team and has nothing to do with Istio.

Remove Istio from the cluster completely:

1.  Uninstall all three Helm releases. Do not delete the Helm release Secrets by hand.
2.  Delete the Istio CRDs, that is, every CRD whose name ends in `istio.io`. Leave `backups.platform.example.com` and any other CRD in place.
3.  Delete the namespaces `istio-system` and `istio-ingress`.
4.  Turn off sidecar injection for `mesh-demo` by removing its injection label. Keep the `mesh-demo` namespace.
5.  Get the **existing** `notification-service` workload out of the mesh: its pod must run without an `istio-proxy` container, and it must be `Ready`. Leave the Deployment and the Service otherwise unchanged. Do not delete them, and do not add a second Deployment.

The grader reads the live cluster: Helm's release Secrets, the Deployments, webhook configurations and cluster roles whose names contain `istio`, the CRDs, the two Istio namespaces, the labels on `mesh-demo`, and the `notification-service` Deployment, Service and pod.
