# Question

Solve this question on: `terminal`

Istio 1.30.5 is installed from the **built-in `demo` profile**, with no changes of any kind: `istiod`, an ingress gateway and an egress gateway are all running in `istio-system`. The namespace `mesh-demo` is labelled for injection and runs one meshed workload, `notification-service`. `istioctl` 1.30.5 is on your PATH.

Change the installation so that all of the following are true at the same time. Keep the configuration in a reusable `IstioOperator` **file**: a YAML document that describes the installation and that you pass to `istioctl install -f`. `--set` flags would pass the checks, but they leave no record behind, and the next install would undo them.

1.  The **egress gateway is gone**. There must be no egress gateway Deployment in the cluster.
2.  The **ingress gateway is still running**. If it is gone too, you switched to the `minimal` profile instead of changing one component of `demo`.
3.  `istiod` requests **`100m`** of CPU.
4.  Envoy access logging is written to **`/dev/stdout`**, mesh-wide.
5.  The mesh-wide outbound traffic policy mode is **`REGISTRY_ONLY`**.
6.  `mesh-demo` is still labelled `istio-injection=enabled`, and `notification-service` is still running and `Ready` with its `istio-proxy` sidecar.

Before you apply anything, use `istioctl` to render your file and confirm your changes came out the way you expect. `istioctl` accepts a component name that matches nothing, or a key in the wrong place, without an error.

The grader reads the live cluster: the Deployments in `istio-system`, the CPU request of `istiod`, the `mesh` key of the `istio` ConfigMap, the `mesh-demo` namespace label, and the `notification-service` pod and its containers.
