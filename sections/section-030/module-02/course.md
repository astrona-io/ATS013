# Canary Upgrade With Revisions And Revision Tags

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS013/tree/main/sections/section-030/module-02/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/module-02/playground
> astrona destroy ats-013-playground-030-02
> ```

Upgrading a service mesh means changing the thing every request already depends on. The safe way to do that is not to change it: you stand up a second control plane beside the first, move one namespace to it, watch, and move the rest only once you believe it. If it goes wrong, the old control plane is still running and still healthy.

That is a **canary upgrade**, and it is the most examinable upgrade topic in the ICA curriculum. It rests on two ideas — a *revision*, which is a named control plane, and a *revision tag*, which is an alias for one — plus a single blunt fact inherited from sidecar injection: nothing moves until a pod is recreated.

## How this module is organised

1. **[Part 1 — Revisions: A Named Control Plane](./course-01-revisions-a-named-control-plane.md)** — what `--set revision=` actually creates, how per-revision webhooks make two control planes coexist, why installing one disturbs nothing, and how to prove which control plane a proxy is attached to.
2. **[Part 2 — Selecting, Moving And Retiring A Revision](./course-02-selecting-moving-retiring.md)** — the labels that pick a control plane, moving a namespace and rolling it back, revision tags as an alias that scales, and the ordering rules for retiring the old revision.

## Learning objectives

After this module you can:

- Explain what a revision is, what objects `--set revision=<name>` creates, and why revision names must be DNS labels.
- Install a second, revisioned control plane beside an existing one without disturbing running workloads.
- Move a namespace between control planes with `istio.io/rev`, and explain why `istio-injection` must be removed first.
- Prove which control plane a given proxy is attached to, using `istioctl proxy-status`.
- Use a revision tag to move workloads between revisions without relabelling namespaces, and roll back by moving the tag.
- Retire an old revision in the correct order relative to restarting workloads, and say what breaks if that order is reversed.

## Before you start

You should be comfortable with sidecar injection and the namespace and pod labels that drive it — [section 020's injection module](../../section-020/module-02/course.md) covers them, and its Part 2 decision table is the direct prerequisite for Part 2 here. You should also know that a control plane upgrade does not touch running proxies.

The playground gives you a single-node `kind` cluster with:

- **Two `istioctl` binaries**, so an upgrade has to be deliberate: `istioctl` is **1.29.8**, the version that is installed; `istioctl-1.30.5` is the upgrade target.
- **Istio 1.29.8 installed with the `demo` profile as the default, unrevisioned control plane** — one `istiod` Deployment, one injection webhook.
- Namespace **`canary-demo`**, labelled `istio-injection=enabled`, running one injected `notification-service` pod.

All commands run from your normal shell with `kubectl` pointed at the cluster.

## Where this fits

This is one of the two upgrade strategies the ICA curriculum names, and the one to default to in production. The other, in-place, is the next module: simpler, cheaper, and with a rollback that costs a second full data-plane restart. Canary buys you a rollback that is a label change, at the price of running two control planes for the duration.

The Helm module before this one covers the mechanics that sit underneath either strategy — where release state lives and how values are computed. Canary upgrades are conventionally driven with `istioctl` because revisions and tags have no direct Helm equivalent.
