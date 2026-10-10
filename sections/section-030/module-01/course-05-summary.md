# Summary

Helm keeps the history of a release inside the cluster. Each install, upgrade and rollback writes a new revision as a Secret of type `helm.sh/release.v1`, named `sh.helm.release.v1.<release>.v<revision>`, in the release's namespace. The Secret holds the rendered manifests, the chart metadata and the values you supplied. `helm ls -A`, `helm history` and `helm get values` read that history back, and `--revision N` reads an older revision. When nobody saved the values file, the release history is the only copy, and deleting those Secrets removes both rollback and recovery.

As soon as you pass any `-f` file or `--set` flag, `helm upgrade` builds the new revision from the chart defaults plus only this run's `-f` files and `--set` flags. It does not carry over the values of the previous revision, and it still reports `deployed` with exit code zero when every setting from the install is gone. Only an upgrade with no values at all reuses the previous values. `--reuse-values` starts from the previous values, but it also keeps the old chart's defaults, including the Istio image tag, and it merges a `-f` file onto the old values, so a key you removed from the file stays. `--reset-then-reuse-values` starts from the new chart's defaults and keeps only your values. The reliable habit is one complete values file per release, saved in version control and passed with `-f` on every run, checked first with `--dry-run --debug`. Lost values come back with `helm get values <release> --revision 1`.

An Istio upgrade with Helm goes `base`, then `istiod`, then each gateway, because a newer `istiod` may use fields that only the newer CRDs accept. Upgrading `istiod` does not change running pods: each sidecar proxy keeps the image the injection webhook wrote into it when the pod was created. That gap is version skew, and Istio supports one minor version of it. `istioctl version` and `istioctl proxy-status` show it, and `kubectl rollout restart` on every meshed namespace and on the gateway closes it. The upgrade is finished when `istioctl version` reports one data plane version.

`helm rollback` applies an older revision of one release again and records it as a new revision. It restores that release's objects and values, including the `istiod` image and `meshConfig`. It does not restart pods, it does not touch the other releases, and it does not undo anything outside the release, such as CRDs or objects created by hand.

Key facts to remember:

- A `helm upgrade` with one `--set` and no `-f` resets every other value to the chart defaults and still reports success.
- Pass the values file a release was installed with on every upgrade of that release.
- `helm upgrade` finishing is not the upgrade finishing; the data plane needs a restart.
- Check the gateways after the upgrade: the `istio/gateway` chart upgrade replaces the gateway pod, and any other gateway needs a `rollout restart`.
- A rollback of `istiod` needs a restart of the workloads too, if the sidecars must follow it.

<!-- astrona:playground:destroy -->
