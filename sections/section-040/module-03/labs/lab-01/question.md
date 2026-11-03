# Question

Solve this question on: `terminal`

Istio 1.30.5 is installed with the `ambient` profile (`istiod`, `istio-cni-node` and `ztunnel`). The profile still supports sidecar injection, and `istioctl` 1.30.5 is on your PATH.

The namespace `sidecar-shop` runs in **sidecar mode**. It has the label `istio-injection=enabled`, and its two workloads, `notification-service` (nginx) and `tester` (curl), each run with an `istio-proxy` sidecar. The bootstrap saved every pod's `metadata.uid` in the ConfigMap `sidecar-shop/lab-baseline`.

Migrate `sidecar-shop` to **ambient mode**.

1.  Remove the `istio-injection` label from the namespace and add the label `istio.io/dataplane-mode=ambient`.
2.  Remove the sidecars. Every pod in `sidecar-shop` must be a new pod: no UID from the baseline may still be running. After the migration each pod has exactly one container and no `istio-proxy`.
3.  Confirm with `istioctl ztunnel-config workload` that both workloads are reported with the `HBONE` protocol.
4.  A request from the `tester` pod to `http://notification-service/` must return HTTP `200`.

Leave the `lab-baseline` ConfigMap, both Deployments and the Service in place. Do not reinstall Istio.
