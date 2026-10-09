# Install Istio With Helm

Astronaut, the same mission control (`istiod`) that `istioctl` builds with one command also ships as Helm charts: flat-pack kits from the shipyard. That is how most production clusters really get Istio, because a pipeline or a GitOps tool (one that keeps a cluster in line with files in a repository) can run `helm upgrade`, but cannot sensibly drive an interactive command-line tool.

The interesting part is not the syntax. Helm does not install "Istio". It installs **three separate releases**, and their order is a dependency, not a habit. The state of those releases also lives in the cluster, not on your disk. Both facts decide how an upgrade later behaves.

## Learning objectives

After this module you can:

- Name the Istio charts, say what each one installs, and explain why the install order is a dependency and not a style choice.
- Install a complete control plane and an ingress gateway as three Helm releases, with mesh settings supplied from a values file.
- Map a Helm value key onto the matching `IstioOperator` field, in both directions.
- Describe where Helm stores a release's state, and read back what a release applied with `helm ls`, `helm get values` and the live `istio` ConfigMap.
- Prove that an install really works by getting a pod injected, instead of trusting a `deployed` status.
- Explain what `helm uninstall` does not remove, and finish the cleanup by hand.

## Before you start

Every mission starts with a pre-flight check, astronaut. Make sure you have the knowledge this module expects, and know what is waiting in your playground.

### What you should already know

- **Kubernetes basics.** Namespaces, Deployments, Services and reading a pod spec with `kubectl`.
- **What Istio installs.** `istiod` is the control plane (mission control). A sidecar is the Envoy proxy injected into each pod (the ship's communications officer). The injection webhook is what adds that sidecar when a pod is created.
- **Basic Helm words.** A *chart* is the package (the kit). A *release* is one installation of that chart under a name. A *values file* supplies the settings (the order form).

### What is in your playground

Your playground is a small training solar system: one `kind` cluster with **`helm` 3** and **`istioctl` 1.30.5** on your PATH, and the **`istio` chart repository already added and updated**. Nothing is installed: `helm ls -A` is empty and the cluster has no Istio CRDs (Custom Resource Definitions).

`istioctl` is there only so you can check what the charts produced. The install itself is pure Helm. You run every command from your normal shell, with `kubectl` already pointed at the cluster.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Work through the parts in this order:

1. [The Chart Model And Its Ordering](./course-01-chart-model-and-ordering.md): the five Istio charts, what each installs, why `base` must come first, and why a gateway is its own release in its own namespace.
2. [Installing The Three Releases](./course-02-installing-the-releases.md): running the installs in order, the values tree and how it maps onto `IstioOperator`, and what `--wait` and `defaultRevision` do.
3. [Release State, Verification And Cleanup](./course-03-release-state-and-verification.md): where Helm keeps what it applied, proving the webhook works from end to end, and what `helm uninstall` leaves behind.
   - Mission: [Install Istio With Helm](./labs/lab-01/question.md)
4. [Wrap-Up: Mission Debrief](./course-04-wrap-up.md)

## Why this matters

`istioctl install` and Helm produce the same objects and read the same configuration tree, but they are two different *owners* of those objects. A cluster where both were used has two sources of truth that quietly overwrite each other, so pick one per cluster. Helm is the better choice whenever the install must be repeatable without a person: automated pipelines, GitOps, or many clusters built from one values file. The exam expects you to install either way.
