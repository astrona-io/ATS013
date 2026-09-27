# Install Istio With Helm

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS013/tree/main/sections/section-010/module-02/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-010/module-02/playground
> astrona destroy ats-013-playground-010-02
> ```

The same control plane you installed with one `istioctl` command is also published as Helm charts — and that is how most clusters in production actually get Istio, because a pipeline or an ArgoCD `Application` can run `helm upgrade` but cannot sensibly run an interactive CLI.

The interesting part is not the syntax. It is that Helm does not install "Istio"; it installs **three separate releases** whose order is a dependency rather than a convention, and that the state of those releases lives in the cluster rather than on your disk. Both facts decide how the upgrade module in section 030 behaves.

## How this module is organised

1. **[Part 1 — The Chart Model And Its Ordering](./course-01-chart-model-and-ordering.md)** — the five Istio charts, what each installs, why `base` must come first, and why a gateway is its own release in its own namespace.
2. **[Part 2 — Installing The Three Releases](./course-02-installing-the-releases.md)** — running the installs in order, the values tree and how it maps onto `IstioOperator`, and what `--wait` and `defaultRevision` are doing.
3. **[Part 3 — Release State, Verification And Cleanup](./course-03-release-state-and-verification.md)** — where Helm keeps what it applied, proving the webhook works end to end, and what `helm uninstall` leaves behind.

## Learning objectives

After this module you can:

- Name the Istio charts, say what each one installs, and explain why the install order is a dependency rather than a style choice.
- Install a complete control plane and an ingress gateway as three Helm releases, with mesh settings supplied from a values file.
- Map a Helm value key onto the equivalent `IstioOperator` field, in both directions.
- Describe where Helm stores a release's state, and read back what a release applied with `helm ls`, `helm get values` and the live `istio` ConfigMap.
- Prove an install is genuinely working by getting a pod injected, rather than trusting a `deployed` status.
- Explain what `helm uninstall` does not remove, and finish the cleanup by hand.

## Before you start

You should already know what a control plane, a sidecar and an injection webhook are — [Module 1](../module-01/course.md) covers them — and be comfortable with basic Helm vocabulary: a *chart* is the package, a *release* is one installation of that chart under a name, and a *values file* supplies the parameters.

The playground gives you a single-node `kind` cluster with **`helm` 3** and **`istioctl` 1.30.5** on your PATH, the **`istio` chart repository already added and updated**, and **nothing installed**: `helm ls -A` is empty and the cluster has no Istio CRDs. `istioctl` is present only so you can verify what the charts produced; the install itself is pure Helm. All commands run in your normal shell with `kubectl` pointed at the cluster.

## Where this fits

`istioctl install` and Helm produce the same objects and read the same configuration tree, but they are two different *owners* of those objects. A cluster where both have been used has two sources of truth that will quietly overwrite each other, so pick one per cluster. Helm wins whenever the install must be reproducible without a human — CI, GitOps, or a fleet of clusters templated from one values file. `istioctl` wins for exploration and for the revision and tag workflow in section 030, which has no direct Helm equivalent.
