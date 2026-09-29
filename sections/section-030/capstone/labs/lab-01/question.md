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

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [istioctl installation](https://istio.io/v1.30/docs/setup/install/istioctl/) — `istioctl install`, `--set`, and what the command actually applies
- [Configuration profiles](https://istio.io/v1.30/docs/setup/additional-setup/config-profiles/) — what each built-in profile turns on
- [Canary upgrades](https://istio.io/v1.30/docs/setup/upgrade/canary/) — revisions, revision labels and moving workloads between control planes
- [Sidecar injection](https://istio.io/v1.30/docs/setup/additional-setup/sidecar-injection/) — the namespace label, the pod annotation, and when injection happens
- [Istio annotations and labels](https://istio.io/v1.30/docs/reference/config/annotations/) — the reference list of both
- [Diagnostic tools](https://istio.io/v1.30/docs/ops/diagnostic-tools/proxy-cmd/) — `proxy-status` and `proxy-config` in full
- [istioctl command reference](https://istio.io/v1.30/docs/reference/commands/istioctl/) — every subcommand and flag
- [Uninstalling Istio](https://istio.io/v1.30/docs/setup/install/istioctl/#uninstall-istio) — removing a control plane or one revision cleanly
