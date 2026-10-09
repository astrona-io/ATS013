# Install Istio With Helm

`istiod` is Istio's control plane: it turns Istio resources into proxy configuration and sends it, together with certificates, to every proxy in the mesh. The same `istiod` that `istioctl install` creates also ships as Helm charts. Helm is a package manager for Kubernetes, and it is how most production clusters really get Istio. A pipeline or a GitOps tool (a tool that keeps a cluster in line with files in a Git repository) can run `helm upgrade`, but it cannot sensibly drive an interactive command-line tool.

The syntax is not the hard part. Helm does not install "Istio" as one thing. It installs **three separate releases**, and their order is a dependency, not a habit. Helm also keeps the state of those releases in the cluster, not on your disk. Both facts decide how an upgrade or a removal behaves later.

`istioctl install` and Helm create the same objects from the same configuration tree, but each one becomes the *owner* of the objects it creates. A cluster where both were used has two sources of truth that overwrite each other, so pick one per cluster. This module uses Helm only.

## Learning objectives

After this module you can:

- Name the Istio charts, say what each one installs, and explain why the install order is a dependency and not a style choice.
- Install a complete control plane and an ingress gateway as three Helm releases, with mesh settings supplied from a values file.
- Map a Helm value key onto the matching `IstioOperator` field, in both directions.
- Describe where Helm stores a release's state, and read back what a release applied with `helm ls`, `helm get values` and the live `istio` ConfigMap.
- Prove that an install really works by getting a pod injected, instead of trusting a `deployed` status.
- Explain what `helm uninstall` does not remove, and finish the removal by hand.

## Before you start

This module expects some Kubernetes knowledge and a little Istio and Helm vocabulary. It starts from a cluster with no Istio at all.

### What you should already know

- **Kubernetes basics.** Namespaces, Deployments, Services and reading a pod spec with `kubectl`.
- **What Istio installs.** `istiod` is the control plane. A sidecar proxy is the Envoy container that Istio adds to each pod; all traffic of the pod passes through it. The sidecar injection webhook is the part that adds that container when a pod is created.
- **Basic Helm words.** A *chart* is a package of Kubernetes object templates. A *release* is one installation of a chart under a name. A *values file* is a YAML file that supplies the settings the templates use.

### What is in your playground

The playground is one single-node `kind` cluster with **`helm` 3** and **`istioctl` 1.30.5** on your PATH, and the **`istio` chart repository already added and updated**. Nothing is installed: `helm ls -A` is empty and the cluster has no Istio CRDs (Custom Resource Definitions, which add new object kinds to the Kubernetes API).

`istioctl` is there only so you can check what the charts produced. The install itself uses Helm only. You run every command from your normal shell, and `kubectl` already points at the cluster.

Start your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Read the parts in this order:

1. **The Chart Model And Its Ordering:** the five Istio charts, what each one installs, why `base` must come first, and why a gateway is its own release in its own namespace.
2. **Installing The Three Releases:** running the installs in order, the values tree and how it maps onto `IstioOperator`, and what `--version`, `--wait` and `defaultRevision` do.
3. **Release State And Verification:** where Helm keeps what it applied, the commands that read it back, and how to prove the injection webhook works from end to end. The graded lab "Install Istio With Helm" follows this part.
4. **Uninstall And Clean Removal:** what `helm uninstall` removes, what it leaves in the cluster on purpose, and how to finish the removal by hand. The graded lab "Remove An Istio Helm Install Completely" follows this part.

A summary closes the module.
