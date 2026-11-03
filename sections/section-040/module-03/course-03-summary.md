# Summary

Istio runs two data planes under one control plane, and the mode is chosen for each namespace. The label `istio-injection=enabled` (or `istio.io/rev`) selects sidecar mode, where the injection webhook in `istiod` adds an `istio-proxy` container when a pod is created. The label `istio.io/dataplane-mode=ambient` selects ambient mode, where `istio-cni-node` and `ztunnel` handle the pods of the namespace at any time and no pod changes.

The two modes look different. A sidecar pod shows an extra container and appears in `istioctl proxy-status`. An ambient pod keeps one container, and only `istioctl ztunnel-config workload` shows its membership, with `HBONE` in the `PROTOCOL` column. The modes share the same control plane and workload identities, so a sidecar pod and an ambient pod can call each other. A pod that has a sidecar is not captured by ztunnel.

The choice follows the need. Ambient mode gives mutual TLS and layer 4 policy with one proxy for each node and no restart on enrollment, and layer 7 features need a waypoint. Sidecar mode keeps a proxy in every pod and needs no `istio-cni` agent.

A migration from sidecar to ambient mode has a fixed order. First swap the labels, then create the pods again so the new pods have no sidecar, then check membership and traffic. Running pods keep their sidecar until they are created again, and a restart before the label swap brings the sidecars back. Layer 7 policies stop being enforced after the move unless a waypoint serves the namespace. The same steps in reverse move a namespace back.

Key facts to remember:

- The mode is selected for each namespace by its label.
- A label change never removes a sidecar from a running pod.
- Swap the labels before the restart.
- Check ambient membership with `istioctl ztunnel-config workload`.

<!-- astrona:playground:destroy -->
