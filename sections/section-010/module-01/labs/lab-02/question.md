# Question

Solve this question on: `terminal`

The cluster runs Istio 1.30.5, installed with `istioctl` and the `demo` profile. `istioctl` 1.30.5 is already on your PATH. The namespace `mesh-demo` carries the label `istio-injection=enabled`. It runs two Deployments, `notification-service` (with a Service of the same name on port `80`) and `tester` (a client pod with `curl`). Both pods run with an `istio-proxy` sidecar container.

The team is moving this cluster off Istio. Remove Istio so the cluster is fully clean and the applications keep working without the mesh:

1.  Remove every Istio control plane and all cluster-wide Istio resources, including the CRDs (Custom Resource Definitions). When you are done, no CRD whose name ends in `istio.io` may remain, and no Istio mutating or validating webhook configuration may remain.
2.  Delete the `istio-system` namespace.
3.  Remove the `istio-injection` label from the `mesh-demo` namespace. Do not set it to another value; remove it.
4.  Make sure no pod in `mesh-demo` still runs an `istio-proxy` container. Keep the `mesh-demo` namespace, both Deployments and the `notification-service` Service. Do not delete or rename them, and do not add another Deployment.
5.  Prove that the applications still work: a request from the `tester` pod to `http://notification-service` must return HTTP status `200`.

The grader reads the live cluster: the `istio-system` namespace, the Istio CRDs and webhook configurations, the labels on `mesh-demo`, the Deployments, the Service and the containers of every pod in `mesh-demo`. It then sends a request from `tester` to `http://notification-service` and expects a `200`.
