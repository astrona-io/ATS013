# Question

Solve this question on: `terminal`

Istio **1.29.8** is installed with the `minimal` profile as the default, unrevisioned control plane. Two namespaces are meshed with `istio-injection=enabled`:

*   `payments` — `checkout-api` at two replicas.
*   `orders` — `order-api` and a `tester` pod.

Two binaries are on your PATH: `istioctl` (1.29.8) and `istioctl-1.30.5` (the target).

Migrate the whole mesh to 1.30.5 using a **canary** upgrade, and finish the job:

1.  Install a second control plane at 1.30.5 as revision **`1-30-5`**, using the `minimal` profile, beside the existing one. Revision names become Kubernetes object names, so they must be DNS labels: dashes, not dots.
2.  Create a revision tag named **`prod`** pointing at `1-30-5`.
3.  Move **both** namespaces onto the new control plane **through the tag**. Each must end up carrying `istio.io/rev=prod` and must **not** carry `istio-injection`.
4.  Restart every meshed workload so the whole data plane is on 1.30.5. All four pods — both `checkout-api` replicas, `order-api` and `tester` — must report revision `1-30-5` and run the 1.30.5 proxy image.
5.  **Then** retire the old control plane. When you are finished there must be no unrevisioned `istiod` Deployment and no unrevisioned `istio-sidecar-injector` webhook, while `istiod-1-30-5` is still running.
6.  Do not use `istioctl uninstall --purge`. It removes **every** revision, including the one you just promoted, along with the shared CRDs.
7.  Leave all four Deployments in place with their original names and replica counts.

The order in requirement 4 before requirement 5 is the point of the exercise: a pod whose control plane has been removed keeps serving on its last configuration but receives no updates and cannot renew its certificate.
