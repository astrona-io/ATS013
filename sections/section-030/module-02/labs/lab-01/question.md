# Question

Solve this question on: `terminal`

Istio **1.29.8** is installed with the `demo` profile as the **default** control plane, with no revision name: one `istiod` Deployment and one injection webhook. The namespace `canary-demo` is labelled `istio-injection=enabled` and runs one workload with a sidecar proxy, `notification-service-v1`.

Two binaries are on your PATH: `istioctl` (1.29.8) and `istioctl-1.30.5` (the target).

Perform a canary upgrade:

1.  Install a **second control plane** at 1.30.5 as revision **`1-30-5`**, using the **`minimal`** profile. A canary upgrade needs a second control plane, not a second set of gateways: a full profile would create two gateway Deployments that compete for the same names. Revision names become Kubernetes object names, so they must be DNS labels: dashes, not dots.
2.  Leave the original control plane **running and untouched**. Both `istiod` and `istiod-1-30-5` must be ready when you are done.
3.  Create a revision tag named **`prod`** that points at revision `1-30-5`.
4.  Move `canary-demo` onto the new control plane **through the tag**, not through a raw revision label. When you are finished, the namespace must carry `istio.io/rev=prod` and must **not** carry `istio-injection`. The two labels rule each other out, and `istio-injection` wins without a warning.
5.  Get the running workload onto the new control plane. Installing a revision and relabelling a namespace changes nothing for pods that already exist.
6.  Leave `notification-service-v1` in place. Do not delete and recreate the Deployment, and do not add a second one.

When you are done, the pod of the workload must run the 1.30.5 proxy image and must report `1-30-5` as its revision.

The grader reads the live cluster: both `istiod` Deployments and the image of the new one, the Deployments of the new revision (no gateways), the `prod` tag webhook, the labels of `canary-demo`, and the containers, proxy image, revision and readiness of the workload's pod.
