# Mix Sidecar And Ambient Mode And Migrate A Namespace

Istio has two data planes: sidecar mode, where every pod has its own Envoy proxy, and ambient mode, where a per-node proxy (`ztunnel`) serves every pod. One cluster, and one `istiod`, can run both at the same time. The mode is chosen for each namespace, so a mesh can start in sidecar mode and move to ambient mode one namespace at a time.

This module explains how the two modes live next to each other, how to see which mode a workload uses, and how to move a namespace from sidecars to ambient mode without breaking traffic. The exam asks for exactly this choice: install Istio in sidecar or in ambient mode, and know what each one needs.

## Learning objectives

After this module you can:

- Name the label that selects each mode and the component that acts on it.
- Tell from a pod and from `istioctl` output which mode a workload uses.
- Explain why a pod that already has a sidecar is not captured by ztunnel.
- Choose between sidecar and ambient mode for a workload with a stated need.
- Migrate a namespace from sidecar to ambient mode and prove the result.

## Before you start

### What you should already know

- **Sidecar injection.** A namespace label makes the injection webhook add the `istio-proxy` container when a pod is created.
- **Ambient enrollment.** The label `istio.io/dataplane-mode=ambient` adds a namespace to the ambient mesh with no pod restart, and `istioctl ztunnel-config workload` shows the members.

### What is in your playground

The playground is a single-node `kind` cluster with **`istioctl` 1.30.5** and Istio installed with the `ambient` profile. The namespace `legacy-shop` runs in sidecar mode and the namespace `new-shop` runs in ambient mode. Each holds `notification-service` and a `tester` pod.

Start your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Read the parts in this order:

1. **Sidecar And Ambient Mode Side By Side:** the label each mode uses, how to tell the modes apart, how they reach each other, and how to choose.
2. **Migrating A Namespace To Ambient Mode:** the steps, the order that matters, and the checks. The graded lab "Migrate A Namespace From Sidecar To Ambient Mode" follows this part.

A summary closes the module.
