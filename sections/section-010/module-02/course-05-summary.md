# Summary

Istio ships as five Helm charts, and a sidecar-mode install needs three of them: `istio/base`, `istio/istiod` and `istio/gateway`. Each chart is installed as its own release, and the chart version matches the Istio version exactly, so `--version 1.30.5` installs Istio 1.30.5. The order is a dependency. `base` comes first because it holds the CRDs (Custom Resource Definitions) that define the Istio object kinds; without them, the Kubernetes API server rejects the objects in the `istiod` chart with an error that names the missing kind. The gateway comes after `istiod` because it gets all of its configuration from `istiod` over xDS, the protocol `istiod` uses to push configuration to running proxies.

A gateway is a separate release, usually in its own namespace, so that a team can manage it without rights in `istio-system`. The chart builds the Deployment name, the Service name and the `istio:` label from the release name, and a `Gateway` resource selects the gateway by those labels. Helm values follow the same tree as `spec.values` in an `IstioOperator`, because `istioctl install` uses the same charts internally. That shared tree is also why using both tools on one cluster gives two owners of the same objects.

A good install creates its namespaces first, pins every chart with `--version`, and uses `--wait` so that each release is ready before the next one starts. `defaultRevision=default` on `base` creates the `istiod-default-validator` webhook, which checks Istio objects that carry no revision label; injection comes from the `istiod` chart, not from this value. In the `istiod` values file, `meshConfig` lands in the `istio` ConfigMap in `istio-system` under the key `mesh`, `pilot` configures the `istiod` Deployment, and `global.proxy` sets defaults for every sidecar proxy, so its resource requests multiply by the number of pods in the mesh. Gateways, routing and security policy are runtime objects, not chart values.

Helm keeps each release revision as a Secret of type `helm.sh/release.v1` in the cluster. `helm ls -A`, `helm history` and `helm get values` read those Secrets back, and deleting them removes the history and the rollback path. `STATUS: deployed` only means the API server accepted the objects. An injected pod with an `istio-proxy` container, and a `SYNCED` line for it in `istioctl proxy-status`, prove that the install really works.

`helm uninstall` removes the release objects and the release record, but it leaves the Istio CRDs, the injection labels on namespaces and the sidecars of running pods in place. A clean removal deletes only the CRDs whose names end in `istio.io`, deletes the Istio namespaces, removes the injection labels and then restarts the workloads so that their new pods have no sidecar.

Key facts to remember:

- Install order: `base`, then `istiod`, then `gateway`; remove in the reverse order.
- Deleting a CRD deletes every object of that kind in every namespace.
- `helm get values` is a recovery tool; a committed values file passed with `-f` is the source of truth.
- The read-only `istioctl` commands are safe on a cluster installed with Helm; `istioctl install` is not.

<!-- astrona:playground:destroy -->
