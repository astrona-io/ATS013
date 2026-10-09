# Canary Upgrade With Revisions And Revision Tags

Upgrading Istio means changing `istiod`, the control plane that every sidecar proxy in the mesh depends on. `istiod` turns Istio resources into proxy configuration and sends it, together with certificates, to every proxy. The safe way to upgrade it is to leave the running `istiod` alone, install a second one next to it, move one namespace over, check it, and only then move the rest. If something goes wrong, the old `istiod` still runs and still serves its proxies.

That method is a **canary upgrade**, and it is one of the most tested upgrade topics on the exam. It rests on two ideas. A **revision** is a named, independent copy of the control plane, so two of them can run side by side. A **revision tag** is a second name that points at one revision, so namespaces can follow the tag instead of a fixed revision. Under both sits one fact about sidecar injection: no workload moves until its pod is created again.

## Learning objectives

After this module you can:

- Explain what a revision is, which objects `--set revision=<name>` creates, and why revision names must be valid DNS labels.
- Install a second control plane, as a revision, next to an existing one without disturbing running workloads.
- Move a namespace between control planes with `istio.io/rev`, and explain why `istio-injection` must be removed first.
- Prove which control plane a proxy is connected to, with `istioctl proxy-status`.
- Use a revision tag to move workloads between revisions without relabelling namespaces, and roll back by moving the tag.
- Retire an old revision in the right order relative to restarting workloads, and say what breaks if you reverse that order.

## Before you start

This module expects you to know how sidecar injection works and how a Deployment replaces its pods.

### What you should already know

- **Sidecar injection.** A mutating admission webhook adds the `istio-proxy` sidecar container to a pod when the pod is created. The namespace label `istio-injection=enabled` turns this on for a whole namespace. Pods that were already running do not change.
- **Upgrades leave proxies behind.** Upgrading the control plane does not touch running proxies. Each proxy keeps the image it was injected with until its pod is created again.
- **Kubernetes basics.** Namespaces, labels, Deployments and `kubectl rollout restart`.

### What is in your playground

The playground is one single-node `kind` cluster with:

- **Two `istioctl` binaries**, so an upgrade only happens when you choose it. Plain `istioctl` is **1.29.8**, the installed version. `istioctl-1.30.5` is the upgrade target.
- **Istio 1.29.8, installed with the `demo` profile as the default control plane with no revision name.** There is one `istiod` Deployment and one injection webhook.
- The namespace **`canary-demo`**, labelled `istio-injection=enabled`, with one Deployment, `notification-service-v1`, whose pod has a sidecar.

You run every command from your normal shell, and `kubectl` already points at the cluster.

Start your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Read the parts in this order:

1. **Revisions: A Named Control Plane:** what `--set revision=` creates, how two control planes run side by side, and why installing one changes nothing for running pods.
2. **Moving A Namespace To A Revision:** the two labels that pick a control plane, which one wins, and the restart that really moves a workload.
3. **Revision Tags:** a second name that points at a revision, so the next upgrade and any rollback is one command instead of one per namespace. The graded lab "Canary Upgrade With Revisions And Tags" follows this part.
4. **Retiring The Old Revision:** the safe order for removing the old control plane, why `--purge` is the wrong tool, and how gateways move. The graded lab "Retire The Old Control Plane Revision" follows this part.

A summary closes the module.
