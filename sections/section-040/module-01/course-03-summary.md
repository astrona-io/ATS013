# Summary

Ambient mode is a second data plane for the same control plane. In sidecar mode Istio adds an Envoy proxy to every pod. In ambient mode the `ambient` profile installs `istiod` plus two DaemonSets, `istio-cni-node` and `ztunnel`, so the mesh runs one proxy per node instead of one per pod. That costs less to run, but one ztunnel serves every pod in the mesh on its node, so its resources and its failures affect the whole node. The profile installs no waypoint proxy and no Gateway API CRDs (Custom Resource Definitions).

The traffic reaches ztunnel without any change to the pod spec. The `istio-cni-node` agent writes the redirect rules into the pod's network namespace from outside the pod, and ztunnel receives the redirected traffic. ztunnel carries it to the destination through HBONE (HTTP-Based Overlay Network Environment): an HTTP/2 tunnel protected by mutual TLS (mTLS) on port 15008. `istio-cni` is required, because without it there is no redirect, and it chains onto the cluster's own network plugin instead of replacing it.

A namespace joins the mesh with the label `istio.io/dataplane-mode=ambient`. `istiod` tells ztunnel about the workloads, and `istio-cni-node` sets up their redirect, so no pod is created again. Removing the label takes the workloads out again, also with no restart. The same label works on a single pod. One namespace uses one mode only, so it never carries both `istio-injection=enabled` and the ambient label.

Because a pod in the ambient mesh keeps its single container, the container count cannot show membership. `istioctl ztunnel-config workload` shows it: `HBONE` in the `PROTOCOL` column means the workload is in the mesh, and `TCP` means it is not. `istioctl ztunnel-config certificate` shows the SPIFFE identities that `istiod` issued, and ztunnel's access log shows both identities and the destination port 15008 for every connection it carries.

ztunnel works at layer 4. It handles mTLS, enforces an `AuthorizationPolicy` that matches on principals, namespaces, IP blocks or ports, and reports connection-level telemetry. Anything that depends on an HTTP method, path, header or status code needs a waypoint proxy. Without one, the API server accepts a layer 7 rule and the rule silently does nothing.

Key facts to remember:

- `istio-cni-node` and `ztunnel` are DaemonSets: one pod of each per node.
- HBONE uses port 15008.
- Enrollment and removal never restart a pod.
- Check membership with `istioctl ztunnel-config workload`, never with the container count.

<!-- astrona:playground:destroy -->
