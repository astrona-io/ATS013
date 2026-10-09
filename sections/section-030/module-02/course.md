# Canary Upgrade With Revisions And Revision Tags

Astronaut, upgrading a service mesh means changing the thing every signal already depends on: mission control. The safe way to do that is not to change it at all. You build a second mission control next to the first, move one planet over, watch, and move the rest only once you trust it. If something goes wrong, the old mission control is still running and still healthy.

That is a **canary upgrade**, and it is one of the most tested upgrade topics on the exam. It rests on two ideas. A **revision** is a named mission control, so two can run side by side. A **revision tag** is a call sign that points at one of them. Under both sits one blunt fact from sidecar injection: nothing moves until a pod is created again.

## Learning objectives

After this module you can:

- Explain what a revision is, which objects `--set revision=<name>` creates, and why revision names must be valid DNS labels.
- Install a second control plane, as a revision, next to an existing one without disturbing running workloads.
- Move a namespace between control planes with `istio.io/rev`, and explain why `istio-injection` must be removed first.
- Prove which control plane a proxy is connected to, with `istioctl proxy-status`.
- Use a revision tag to move workloads between revisions without relabelling namespaces, and roll back by moving the tag.
- Retire an old revision in the right order relative to restarting workloads, and say what breaks if you reverse that order.

## Before you start

Every mission starts with a pre-flight check, astronaut. Make sure you have the knowledge this module expects, and know what is waiting in your playground.

### What you should already know

- **Sidecar injection.** A webhook (a dock inspector) adds the `istio-proxy` sidecar to a pod when the pod is created. The namespace label `istio-injection=enabled` turns this on for a whole namespace. Pods that were already running are not changed.
- **Upgrades leave proxies behind.** Upgrading the control plane does not touch running proxies. Each one keeps the image it was injected with until its pod is recreated.
- **Kubernetes basics.** Namespaces, labels, Deployments and `kubectl rollout restart`.

### What is in your playground

Your playground is a training solar system: one `kind` cluster with:

- **Two `istioctl` binaries**, so an upgrade has to be on purpose. Plain `istioctl` is **1.29.8**, the installed version. `istioctl-1.30.5` is the upgrade target.
- **Istio 1.29.8, installed with the `demo` profile as the default control plane with no revision name.** There is one `istiod` Deployment and one injection webhook.
- The namespace **`canary-demo`**, labelled `istio-injection=enabled`, with one Deployment, `notification-service-v1`, whose pod has a sidecar.

Every command runs from your normal shell, with `kubectl` already pointing at the cluster.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Work through the parts in this order. The mission comes right after the part it practises.

1. [Revisions: A Named Control Plane](./course-01-revisions-a-named-control-plane.md): what `--set revision=` creates, how two control planes live side by side, and why installing one changes nothing for running pods.
2. [Moving A Namespace To A Revision](./course-02-moving-a-namespace-to-a-revision.md): the two labels that pick a control plane, which one wins, and the restart that really moves a workload.
3. [Revision Tags](./course-03-revision-tags.md): a call sign that points at a revision, so the next upgrade and any rollback is one command instead of one per namespace.
   - Mission: [Canary Upgrade With Revisions And Tags](./labs/lab-01/question.md)
4. [Retiring The Old Revision](./course-04-retiring-the-old-revision.md): the safe order for removing the old control plane, why `--purge` is the wrong tool, and how gateways move.
5. [Wrap-Up: Mission Debrief](./course-05-wrap-up.md)

## Why this matters

There are two upgrade strategies. An **in-place** upgrade replaces the one mission control; it is simpler, but going back means a second full round of restarts. A **canary** upgrade costs a second mission control for a while, and in return going back is a label change. That is why production clusters usually start here.

Canary upgrades are normally done with `istioctl`, because revisions and tags have no direct Helm command of their own. Learn how a revision is named, how a planet picks one, and when the ships really move, and an upgrade becomes something you can stop and reverse at any point.
