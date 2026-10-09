# Install Istio With istioctl

Astronaut, everything else Istio does (routing, mutual TLS, authorization, telemetry) depends on one control plane process called `istiod`. It is mission control for your fleet. This module is about building mission control in your solar system (your cluster) with `istioctl`, your launch console: getting it onto the cluster, seeing exactly what it created, and taking it away again cleanly.

The command is one line. It is worth four parts because `istioctl install` is *declarative*: it does not "add Istio". It draws a complete blueprint and makes the cluster match it. Almost every surprise people meet later comes from that one sentence: a second install that removed a gateway, a namespace label that changed nothing, an uninstall that left the cluster dirty.

## Learning objectives

After this module you can:

- Describe the stages `istioctl install` runs through, and explain why no operator pod keeps your `IstioOperator` in place afterwards.
- List what `default`, `demo`, `minimal` and `ambient` each install, and compare two of them by comparing their printed objects.
- Name the control plane, webhook, CRD (Custom Resource Definition) and gateway objects an install creates, and say what each one is for.
- Switch on sidecar injection for a namespace, explain why existing pods are not affected, and prove that a new pod received a proxy.
- Find a version mismatch between the client, the control plane and the data plane with `istioctl version` and `istioctl proxy-status`.
- Predict what a second `istioctl install` does to settings the new document leaves out, and remove Istio so the next install starts clean.

## Before you start

Every mission starts with a pre-flight check, astronaut. Make sure you have the knowledge this module expects, and know what is waiting in your playground.

### What you should already know

- **Kubernetes basics.** Namespaces, Deployments, and reading a pod spec with `kubectl`, on a cluster where you have administrator rights.
- **No Istio yet.** This module starts from zero.

### What is in your playground

Your playground is a small training solar system: one `kind` cluster with **`istioctl` 1.30.5 already installed** and **no Istio at all**. There is no `istio-system` namespace, no Istio CRDs and no webhooks. You run everything from your normal shell, with `kubectl` already pointed at the cluster.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Work through the parts in this order:

1. [The Render-And-Apply Pipeline](./course-01-render-and-apply-pipeline.md): what `istioctl install` does on your machine before anything reaches the cluster, why no operator pod exists, and what `istioctl x precheck` really checks.
2. [Profiles And The Objects They Produce](./course-02-profiles-and-installed-objects.md): profiles as documents, not presets; how to print them; and a list of the control plane, webhooks, CRDs and gateways an install creates.
3. [Injection And The Version Triad](./course-03-injection-and-version-alignment.md): how a pod gets a sidecar, why labelling a namespace changes nothing on its own, and how to read `istioctl proxy-status` when versions disagree.
4. [Reconciliation And Clean Removal](./course-04-reconciliation-and-removal.md): what a second install does to settings you left out, how Istio decides what to delete, and the difference between `--revision` and `--purge`.
   - Mission: [Install Istio With istioctl](./labs/lab-01/question.md)
5. [Wrap-Up: Mission Debrief](./course-05-wrap-up.md)

## Why this matters

`istioctl` is one of two supported ways to install Istio; Helm is the other. Both install the same control plane, but they are different owners of the same objects, so a cluster is managed by one or the other, never both. People usually pick `istioctl` when a person runs the install by hand. The exam asks for "istioctl **or** Helm" because you are expected to be fluent in both, and every later task assumes you can build mission control and prove it is healthy.
