# Question

Solve this question on: `terminal`

Istio 1.30.5 is installed with the `default` profile. Namespace `inject-demo` carries **no injection label** and runs three Deployments, each with one container:

*   `notification-service` — an nginx web server that belongs in the mesh.
*   `logging-agent` — a log shipper that must stay **out** of the mesh.
*   `batch-job` — a job that must be in the mesh **explicitly**, not because the namespace happens to be labelled.

Produce this end state:

1.  `inject-demo` is opted in using the label that selects the **default** control plane.
2.  `notification-service` is running with an `istio-proxy` sidecar.
3.  `logging-agent` is running with **exactly one container**, excluded by `sidecar.istio.io/inject` set to `"false"`.
4.  `batch-job` is running with an `istio-proxy` sidecar **and** carries `sidecar.istio.io/inject` set to `"true"`, so its membership does not depend on the namespace label at all.
5.  All three Deployments still exist, are `Available`, and keep their original names. Do not delete and recreate them, and do not add a fourth.

Two details the grader is strict about, because both are silent failures in the real world:

*   The `sidecar.istio.io/inject` labels must be on the **pod template** (`spec.template.metadata.labels`). The webhook is registered against Pods and never sees your Deployment, so a label on the Deployment's own `metadata.labels` applies cleanly and does nothing.
*   Label values are strings. `"true"` and `"false"` must be quoted — an unquoted YAML boolean is rejected by the API server.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [Install with Helm](https://istio.io/v1.30/docs/setup/install/helm/) — the charts, their values, and install ordering
- [Canary upgrades](https://istio.io/v1.30/docs/setup/upgrade/canary/) — revisions, revision labels and moving workloads between control planes
- [Sidecar injection](https://istio.io/v1.30/docs/setup/additional-setup/sidecar-injection/) — the namespace label, the pod annotation, and when injection happens
- [Istio annotations and labels](https://istio.io/v1.30/docs/reference/config/annotations/) — the reference list of both
- [Diagnostic tools](https://istio.io/v1.30/docs/ops/diagnostic-tools/proxy-cmd/) — `proxy-status` and `proxy-config` in full
- [istioctl command reference](https://istio.io/v1.30/docs/reference/commands/istioctl/) — every subcommand and flag
