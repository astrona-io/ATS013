# Question

Solve this question on: `terminal`

Istio **1.29.8** is installed with the `default` profile as the single default revision: one `istiod` (the control plane) and one ingress gateway in `istio-system`. The namespace `inplace-demo` is in the mesh and runs `notification-service-v1` at **two replicas** plus a `tester` pod. Every pod in `inplace-demo` has a sidecar proxy.

Two binaries are on your PATH: `istioctl` (1.29.8) and `istioctl-1.30.5` (the target).

Upgrade to **1.30.5 in place**:

1.  Run the pre-upgrade check with the **target version's** binary and read the output. The check asks whether *this cluster* can accept *that version*, so the old binary is the wrong tool for it.
2.  Upgrade the control plane in place, keeping the **same `default` profile** it was installed with. `istioctl install` makes the cluster match the configuration you pass. A bare `istioctl install -y` would make it match the default profile and throw away configuration.
3.  This must be an **in-place** upgrade, not a canary. When you are done there must be exactly **one** `istiod` Deployment in `istio-system`, and no control plane or webhook with a revision name.
4.  The profile's ingress gateway must still be running.
5.  End the version skew, that is, proxies that still run the old version after the control plane is upgraded. Every proxy in the mesh (both application replicas, the `tester` pod, **and the ingress gateway**) must run the 1.30.5 proxy image.
6.  Leave the Deployments in place. Do not delete and recreate them, and do not add any.

The grader reads the live cluster: the number of `istiod` Deployments in `istio-system`, any injection webhook with a revision name, the `istiod` image, the ingress gateway's pod and its proxy image, the Deployments and ready replicas in `inplace-demo`, and the `istio-proxy` image of every running pod in `inplace-demo`.
