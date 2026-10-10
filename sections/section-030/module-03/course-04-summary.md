# Summary

An in-place upgrade replaces the control plane, `istiod`, under the same revision. Every object in `istio-system` keeps its name, and the `istiod` Deployment keeps its `uid`; only its image changes. That is why nothing needs to be relabelled, and also why no old control plane is left to fall back to. The upgrade has three steps: check the cluster, install the new version, and restart every workload with a sidecar proxy.

The check is `istioctl x precheck`, run with the target version's binary, because only that binary knows the target's requirements and deprecated fields. The install is `istioctl install` with the new binary and the same configuration the cluster was installed with, for example `istioctl-1.30.5 install --set profile=default -y`. A bare `istioctl install -y` makes the cluster match the `default` profile and resets custom settings. While a single `istiod` pod restarts, existing proxies keep forwarding traffic, but configuration pushes wait and the API server rejects new pods in namespaces with injection.

After the control plane is new, every proxy still runs the image it was injected with. This is version skew, and Istio supports a gap of one minor version, so you never skip a minor version. `kubectl rollout restart deployment` ends the skew by replacing pods a few at a time, and the ingress gateway in `istio-system` needs its own restart. The upgrade is complete when `istioctl version` shows one data plane version that matches the control plane.

Going back from an in-place upgrade means reinstalling the old version with the old configuration and restarting the whole data plane again. A canary upgrade only moves a namespace label or a revision tag back. In-place fits patch releases, development clusters and small meshes; on a large production mesh, the count of pods to restart usually decides.

Key facts to remember:

- Run `istioctl x precheck` with the target binary before the upgrade, and `istioctl analyze` after it.
- `istioctl upgrade` is an alias for `istioctl install`; neither restarts workloads.
- Two `istiod` replicas remove the short gap with no ready control plane.
- Export the installed configuration before you start, or you have no way back.

<!-- astrona:playground:destroy -->
