# Customize An Istio Installation

A built-in profile gives you a working Istio control plane, but almost never the exact one a cluster needs. You may not want the egress gateway. You may want Envoy access logs on every proxy. The CPU that `istiod` requests may be wrong for your nodes. This module shows how to change those things with the same `istioctl install` command, by passing it a file instead of only a profile name.

That file is an `IstioOperator` document: a YAML description of the whole Istio installation you want. It has four places where a setting can live, and each place takes effect on a different object. If you put a setting in the wrong place, the install succeeds and the setting does nothing at all.

## Learning objectives

After this module you can:

- Name the four configuration layers in an `IstioOperator` document, say which one owns a given setting, and say how they merge.
- Decide whether a requirement belongs in the installation or in a runtime resource, and explain why.
- Follow a `meshConfig` setting from your file, to the `istio` ConfigMap, to a single proxy, and use each step to narrow down a fault.
- Write an `IstioOperator` file that turns off a component, sets mesh-wide behaviour and sizes the control plane, and check it before you apply it.
- Compare an installation with the profile it started from by comparing rendered manifests.
- Predict what a second `istioctl install` does to settings the new document does not mention.

## Before you start

This module expects some Kubernetes knowledge and a basic idea of how Istio is installed.

### What you should already know

- **Kubernetes basics.** Namespaces, Deployments, ConfigMaps and reading a pod spec with `kubectl`.
- **Installing Istio with `istioctl`.** You know that `istiod` is Istio's control plane, that a gateway is a standalone Envoy proxy at the edge of the mesh, and that a sidecar injection webhook adds a proxy to new pods. You also know that `istioctl install` makes the cluster match the document you pass, and removes Istio objects that the document no longer describes.

### What is in your playground

The playground is one single-node `kind` cluster with **`istioctl` 1.30.5** on your PATH. **Istio 1.30.5 is already installed with the built-in `demo` profile**: `istiod`, an ingress gateway and an egress gateway run in `istio-system`, with no changes of any kind.

That unchanged starting point matters. Every difference you see later is one you caused. You run every command from your normal shell, and `kubectl` already points at the cluster.

Start your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Read the parts in this order:

1. **The Four Configuration Layers:** what `profile`, `components`, `meshConfig` and `values` each own, how they merge, and where the line runs between installation settings and runtime resources.
2. **meshConfig: From File To ConfigMap To Proxy:** the path a mesh-wide setting takes, why the `istio` ConfigMap is the fastest place to check it, and how `REGISTRY_ONLY` changes real traffic.
3. **Writing, Validating And Re-applying The Document:** how to build the `IstioOperator` file, the list rule that hides typos, how to compare with the built-in profile, and what a second install does to settings you left out. The graded lab "Customize An Istio Installation" follows this part.

A summary closes the module.
