# Upgrade And Reconfigure Istio With Helm

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS013/tree/main/sections/section-030/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/module-01/playground
> astrona destroy ats-013-playground-030-01
> ```

`helm upgrade` has a default that surprises people exactly once, and the incident report usually reads "the upgrade succeeded and the mesh started behaving differently". The command computes the new release from the chart plus **the values you pass on this run** — not the values from last time. Anything you set at install and do not repeat is gone, and Helm reports success because, from its point of view, you got what you asked for.

This module is about upgrading a Helm-managed Istio without losing configuration: where the previous state actually lives, what the value flags really do, and why finishing an upgrade takes one more step after the control plane is new.

## How this module is organised

1. **[Part 1 — Where A Release Lives](./course-01-where-a-release-lives.md)** — the Secret behind every release, revision numbering, and the four read commands that tell you what a cluster is running and how it is configured.
2. **[Part 2 — How `helm upgrade` Computes Values](./course-02-how-upgrade-computes-values.md)** — the default merge, `--reuse-values` and `--reset-values`, the silent-loss failure demonstrated on purpose, and recovering a values file from a previous revision.
3. **[Part 3 — Executing And Reverting An Upgrade](./course-03-executing-and-reverting.md)** — chart order, the data-plane restart that actually completes the upgrade, version skew, and exactly what `helm rollback` does and does not restore.

## Learning objectives

After this module you can:

- Describe where Helm stores a release's manifests and values, and read an older revision's values back out of the cluster.
- Explain how `helm upgrade` computes values, and predict the effect of `--reuse-values` and `--reset-values`.
- Recover configuration that exists only inside a release and rebuild a committed values file from it.
- Upgrade `base`, `istiod` and a gateway to a new version in the correct order without losing mesh settings.
- Identify control-plane / data-plane version skew with `istioctl proxy-status` and complete the upgrade.
- Roll a release back to a previous revision and state what the rollback leaves untouched.

## Before you start

You should be able to install Istio with Helm and read back what a release applied — [section 010's Helm module](../../section-010/module-02/course.md) covers both, and its Part 3 on release state is the direct prerequisite for Part 1 here. You should also know what `meshConfig` is and where it lands.

The playground gives you a single-node `kind` cluster with **`helm` 3** and **`istioctl` 1.29.8** on your PATH, the `istio` chart repository added, and **Istio 1.29.8 installed as three Helm releases**: `istio-base` and `istiod` in `istio-system`, `istio-ingressgateway` in `istio-ingress`, each at revision 1. One injected workload, `notification-service`, runs in the `default` namespace.

One detail is deliberate and matters for the whole module: `istiod` was installed with a **non-default values file that no longer exists on disk**. Access logging is on, autoscaling is off, and there are explicit resource requests — and the only record of that is inside the release. That is the situation you inherit far more often than a clean one.

## Where this fits

Istio has two upgrade *strategies* and this module is neither of them in the strict sense — it is the mechanics underneath both. A **canary** upgrade installs a second control plane beside the first and moves workloads gradually; an **in-place** upgrade replaces the single control plane. Those are the next two modules, and both are conventionally driven with `istioctl`.

What you do with Helm is a version bump of the releases, which behaves like an in-place upgrade: one control plane, replaced. Learning the Helm path separately matters because its failure mode is different. `istioctl install` reconciles to a file you can read; `helm upgrade` reconciles to an argument list you might have got wrong, against a previous state you might not have.
