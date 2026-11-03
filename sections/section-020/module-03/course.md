# Customize Gateways And Control Plane Resources

Mesh-wide settings are one half of a customized install. The other half is shaping the Kubernetes objects Istio creates: how many replicas a gateway runs, what its Service looks like, and how much CPU and memory each component asks for. On a real cluster these settings decide whether the ingress gateway is reachable and whether it survives load.

In an `IstioOperator` file all of this lives under `spec.components`. Each component, such as `pilot` (the name for `istiod`) or an ingress gateway, has an `enabled` flag and a `k8s` block that overrides the Kubernetes objects of that component. This module teaches the layout of that block and uses it to turn the ingress gateway into a `NodePort` Service with its own autoscaling and resource requests.

## Learning objectives

After this module you can:

- Name the entries under `spec.components` and say what `enabled` does for each.
- Set resource requests, replicas, an autoscaler and a node selector for a component with the `k8s` block.
- Change the type and ports of the ingress gateway Service, and explain why `kind` needs `NodePort`.
- Set the bounds of the gateway's `HorizontalPodAutoscaler` with `hpaSpec`.
- Render a change with `istioctl manifest generate` before you apply it, and prove the result on the live objects.

## Before you start

### What you should already know

- **An `IstioOperator` file.** It is the input of `istioctl install -f`, and a profile supplies the defaults under it.
- **Kubernetes Services.** The types `ClusterIP`, `NodePort` and `LoadBalancer`, and what a `HorizontalPodAutoscaler` does.

### What is in your playground

The playground is a single-node `kind` cluster with **`istioctl` 1.30.5** and Istio installed with the `default` profile. The namespace `gw-demo` runs `notification-service` and a `tester` pod, published through the ingress gateway with a `Gateway` and a `VirtualService`.

Start your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Read the parts in this order:

1. **The components Block And k8s Settings:** the list of components and the fields that every `k8s` block accepts.
2. **Shaping The Ingress Gateway Service And Scaling:** the `NodePort` Service, the autoscaler and the resource requests, written, rendered, applied and proved. The graded lab "Customize The Ingress Gateway With IstioOperator" follows this part.

A summary closes the module.
