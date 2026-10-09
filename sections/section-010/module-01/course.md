# Install Istio With istioctl

Everything Istio does (routing, mutual TLS, authorization, telemetry) depends on one control plane process called `istiod`. `istiod` turns Istio resources into proxy configuration and sends it, together with certificates, to every proxy in the mesh. This module shows how to install `istiod` with `istioctl`, the Istio command-line tool, how to see exactly what the install created, and how to remove it again cleanly.

The install command is one line, but `istioctl install` is *declarative*: you describe the end state, and the tool makes the cluster match it. It does not "add Istio". Most surprises people meet later come from that fact: a second install that removed a gateway, a namespace label that changed nothing, an uninstall that left objects behind.

`istioctl` is one of the two supported ways to install Istio; Helm is the other. Both install the same control plane, but each one owns the objects it creates, so a cluster is managed by one or the other, never both.

## Learning objectives

After this module you can:

- Describe the stages `istioctl install` runs through, and explain why no operator pod keeps your `IstioOperator` document in place afterwards.
- List what the `default`, `demo`, `minimal` and `ambient` profiles each install, and compare two profiles by comparing the objects they render.
- Name the control plane, webhook, CRD (Custom Resource Definition) and gateway objects an install creates, and say what each one does.
- Turn on sidecar injection for a namespace, explain why existing pods do not change, and prove that a new pod received a proxy.
- Find a version mismatch between the client, the control plane and the data plane with `istioctl version` and `istioctl proxy-status`.
- Predict what a second `istioctl install` does to settings the new document leaves out, and remove Istio so the next install starts clean.

## Before you start

This module expects some Kubernetes knowledge and starts from a cluster with no Istio at all.

### What you should already know

- **Kubernetes basics.** Namespaces, Deployments, and reading a pod spec with `kubectl`, on a cluster where you have administrator rights.
- **No Istio knowledge.** This module starts from zero.

### What is in your playground

The playground is one single-node `kind` cluster with **`istioctl` 1.30.5 already installed** and **no Istio in the cluster**. There is no `istio-system` namespace, no Istio CRDs and no Istio webhooks. You run every command from your normal shell, and `kubectl` already points at the cluster.

Start your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Read the parts in this order:

1. **The Render-And-Apply Pipeline:** what `istioctl install` does on your machine before anything reaches the cluster, why no operator pod exists, and what `istioctl x precheck` checks.
2. **Profiles And The Objects They Produce:** what a profile is, how to print one, and the control plane, webhooks, CRDs and gateways an install creates.
3. **Injection And The Version Triad:** how a pod gets a sidecar proxy, why labelling a namespace does not change running pods, and how to read `istioctl version` and `istioctl proxy-status`. The graded lab "Install Istio With istioctl" follows this part.
4. **Reconciliation And Clean Removal:** what a second install does to settings you left out, how `istioctl` decides what to delete, and the difference between `--revision` and `--purge`. The graded lab "Remove Istio Completely With istioctl" follows this part.

A summary closes the module.
