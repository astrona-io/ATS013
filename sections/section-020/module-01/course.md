# Customize An Istio Installation

Astronaut, a stock profile gets mission control running. It almost never gets it running the way your solar system needs. Maybe you do not want the departure gate (the egress gateway). Maybe you do want a flight log (access logs). Maybe the computer power reserved for mission control is wrong for your launch pads.

Changing those things is not a new skill. You use the same `istioctl install` command, but you hand it a blueprint file instead of just a profile name. That blueprint is an `IstioOperator` document. It has four places where a setting can live, and they behave differently. Pick the wrong place, and a change applies cleanly and does nothing at all.

## Learning objectives

After this module you can:

- Name the four configuration layers in an `IstioOperator` document, say which one owns a given setting, and say how they merge.
- Decide whether a requirement belongs in the installation or in a runtime resource, and explain why.
- Follow a `meshConfig` setting from your file, to the `istio` ConfigMap, to a single proxy, and use each step to narrow down a fault.
- Write an `IstioOperator` file that turns off a component, sets mesh-wide behaviour and sizes the control plane, and check it before you apply it.
- Compare an installation with the profile it started from by comparing rendered manifests.
- Predict what a second `istioctl install` does to settings the new document does not mention.

## Before you start

Every mission starts with a pre-flight check, astronaut. Make sure you have the knowledge this module expects, and know what is waiting in your playground.

### What you should already know

- **Kubernetes basics.** Namespaces, Deployments, ConfigMaps and reading a pod spec with `kubectl`.
- **Installing Istio with `istioctl`.** You know what `istiod` (mission control), a gateway and the sidecar injection webhook are. You also know that `istioctl install` makes the cluster match the document you pass, and removes Istio objects that the document no longer describes.

### What is in your playground

Your playground is a small training solar system: one `kind` cluster with **`istioctl` 1.30.5** on your path. **Istio 1.30.5 is already installed with the stock `demo` profile**: `istiod`, an ingress gateway and an egress gateway in `istio-system`, with no changes of any kind.

That untouched starting point is the point. Every difference you see later is one you caused. All commands run from your normal shell, with `kubectl` already pointed at the cluster.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Work through the parts in this order. The mission comes right after the part it practises.

1. [The Four Configuration Layers](./course-01-the-four-configuration-layers.md): `profile`, `components`, `meshConfig` and `values`, what each one owns, how they merge, and the line between installation settings and runtime resources.
2. [meshConfig: From File To ConfigMap To Proxy](./course-02-meshconfig-from-file-to-proxy.md): the full path a mesh-wide setting travels, why the `istio` ConfigMap is your fastest debugging tool, and watching `REGISTRY_ONLY` change real traffic.
3. [Writing, Validating And Re-applying The Document](./course-03-writing-validating-reapplying.md): building the `IstioOperator` file, the list rule that hides typos, comparing with a baseline, and what a second install does to what you left out.
   - Mission: [Customize An Istio Installation](./labs/lab-01/question.md)
4. [Wrap-Up: Mission Debrief](./course-04-wrap-up.md)

## Why this matters

On the exam, and on a real cluster, "install Istio" almost always comes with conditions: drop this gateway, log to standard output, block unknown destinations. Knowing which layer owns a setting, and where to look to prove it arrived, turns those conditions into a few minutes of work instead of a guessing game.
