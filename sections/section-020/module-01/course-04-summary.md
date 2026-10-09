# Summary

An `IstioOperator` document is the YAML file you pass to `istioctl install`, and it has four layers. `profile` picks a built-in document such as `demo`. `components` decides which components exist and how they run as Kubernetes workloads, with Kubernetes settings under the fixed `k8s:` sub-key. `meshConfig` holds mesh-wide settings that change what the proxies do, and `values` passes settings straight to the Helm charts inside `istioctl`. When `components` and `values` set the same thing, `components` wins, but the better habit is to use the structured field and never set one thing twice.

`istioctl` builds one document from the profile, then your `-f` files in order, then your `--set` flags, and the merge is per field, not per block. Lists under `components` are the exception: `istioctl` matches their entries by `name`, and a name that matches nothing adds a new entry instead of changing the existing one. Installation settings are mesh-wide by design. A requirement for one workload or one namespace belongs in a runtime resource such as a `Telemetry`, `ServiceEntry` or `DestinationRule`, which takes effect in seconds without a new install.

A `meshConfig` setting travels from your file to the `istio` ConfigMap in `istio-system`, then to `istiod`, which pushes it to every proxy over xDS. Each stop has its own check: `istioctl validate -f` and `istioctl manifest generate -f` for the file, the ConfigMap's `mesh` key for the cluster, `istioctl proxy-status` for the push, and a real request for enforcement. With `outboundTrafficPolicy.mode: REGISTRY_ONLY`, the sidecar proxy answers a request to a host outside the mesh registry with `502`, while Services inside the cluster keep working. A proxy that has not received the push, or a more specific runtime resource, explains a workload that does not follow the ConfigMap.

`istioctl install` makes the cluster match the document it receives. A second install with a different document, or with only `--set profile=demo`, reverts every change the new document leaves out, with no warning. Rendering the built-in profile and your file with `istioctl manifest generate` and comparing the two shows exactly what you changed, before anything reaches the cluster.

Key facts to remember:

- `components.pilot` is the `istiod` Deployment; `components.pilot.k8s.resources` sizes `istiod`, and `values.global.proxy.resources` sizes every sidecar.
- `istioctl validate -f` checks the schema; only `istioctl manifest generate -f` shows whether your change is in the result.
- A key missing from the `istio` ConfigMap means the built-in default applies.
- A hand edit of the `istio` ConfigMap lasts only until the next `istioctl install`.
- Keep one `IstioOperator` file per control plane in version control, and pass it on every install.

<!-- astrona:playground:destroy -->
