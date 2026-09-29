# Question

Solve this question on: `terminal`

Istio **1.29.8** is installed with the `demo` profile as the **default, unrevisioned** control plane — one `istiod` Deployment, one injection webhook. Namespace `canary-demo` is labelled `istio-injection=enabled` and runs one injected workload, `notification-service-v1`.

Two binaries are on your PATH: `istioctl` (1.29.8) and `istioctl-1.30.5` (the target).

Perform a canary upgrade:

1.  Install a **second control plane** at 1.30.5 as revision **`1-30-5`**, using the **`minimal`** profile. A canary needs a second control plane, not a second copy of the gateways — a full profile would put two gateway Deployments in contention for the same names. Revision names become Kubernetes object names, so they must be DNS labels: dashes, not dots.
2.  Leave the original control plane **running and untouched**. Both `istiod` and `istiod-1-30-5` must be ready when you are done.
3.  Create a revision tag named **`prod`** pointing at revision `1-30-5`.
4.  Move `canary-demo` onto the new control plane **through the tag**, not through a raw revision label. When you are finished the namespace must carry `istio.io/rev=prod` and must **not** carry `istio-injection` — the two are mutually exclusive in effect, and `istio-injection` wins silently.
5.  Get the running workload onto the new control plane. Installing a revision and relabelling a namespace changes nothing for pods that already exist.
6.  Leave `notification-service-v1` in place — do not delete and recreate the Deployment, and do not add a second one.

When you are done, the workload's pod must be running the 1.30.5 proxy image and must report `1-30-5` as its revision.

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
