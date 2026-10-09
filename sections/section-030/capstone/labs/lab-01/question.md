# Question

Solve this question on: `terminal`

This capstone lab asks you to move every workload to a new control plane revision, then remove the old control plane, in the right order.

Istio **1.29.8** is installed with the `minimal` profile as the default control plane, with no revision name. Two namespaces are in the mesh with `istio-injection=enabled`:

*   `payments`: `checkout-api` at two replicas.
*   `orders`: `order-api` and a `tester` pod.

Two binaries are on your PATH: `istioctl` (1.29.8) and `istioctl-1.30.5` (the target).

Move the whole mesh to 1.30.5 with a **canary** upgrade, and finish the job:

1.  Install a second control plane at 1.30.5 as revision **`1-30-5`**, using the `minimal` profile, next to the existing one. Revision names become Kubernetes object names, so they must be DNS labels: dashes, not dots.
2.  Create a revision tag named **`prod`** that points at `1-30-5`.
3.  Move **both** namespaces onto the new control plane **through the tag**. Each must end up carrying `istio.io/rev=prod` and must **not** carry `istio-injection`.
4.  Restart every workload in the mesh so the whole data plane is on 1.30.5. All four pods (both `checkout-api` replicas, `order-api` and `tester`) must report revision `1-30-5` and run the 1.30.5 proxy image.
5.  **Then** retire the old control plane. When you are finished there must be no `istiod` Deployment and no `istio-sidecar-injector` webhook without a revision name, while `istiod-1-30-5` is still running.
6.  Do not use `istioctl uninstall --purge`. It removes **every** revision, including the one you just promoted, along with the shared Custom Resource Definitions (CRDs).
7.  Leave all four Deployments in place, with their original names and replica counts.

Doing requirement 4 before requirement 5 is the point of the exercise. A pod whose control plane has been removed keeps serving on its last configuration, but it gets no updates and cannot renew its certificate.
