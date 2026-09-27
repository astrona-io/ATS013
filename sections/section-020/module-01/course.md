# Customize An Istio Installation

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS013/tree/main/sections/section-020/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-020/module-01/playground
> astrona destroy ats-013-playground-020-01
> ```

A profile gets Istio running. It almost never gets Istio running the way your cluster needs it: the egress gateway you do not want, the access logs you do want, the CPU request that is wrong for your nodes. Changing those is not a different skill from installing — it is the same `istioctl install` command with a document behind it instead of a profile name.

This module is about that document. There are four places a setting can live in it, they behave differently, and picking the wrong one is why a change sometimes applies cleanly and does nothing at all.

## How this module is organised

1. **[Part 1 — The Four Configuration Layers](./course-01-the-four-configuration-layers.md)** — `profile`, `components`, `meshConfig` and `values`: what each one owns, how they merge, and the install-time / runtime boundary that decides whether a requirement belongs here at all.
2. **[Part 2 — meshConfig: From File To ConfigMap To Proxy](./course-02-meshconfig-from-file-to-proxy.md)** — the full path a mesh-wide setting travels, why the `istio` ConfigMap is the fastest debugging tool you have, and watching `REGISTRY_ONLY` change real traffic.
3. **[Part 3 — Writing, Validating And Re-applying The Document](./course-03-writing-validating-reapplying.md)** — building the `IstioOperator` file, the list-matching rule that silently swallows typos, diffing against a baseline, and what a second install does to what you left out.

## Learning objectives

After this module you can:

- Name the four configuration layers in an `IstioOperator`, say which one owns a given setting, and state the order they merge in.
- Decide whether a requirement is install-time configuration or a runtime resource, and justify the answer.
- Trace a `meshConfig` setting from your file to the `istio` ConfigMap to an individual proxy, and use each step to narrow a fault.
- Write an `IstioOperator` file that disables a component, sets mesh-wide behaviour and sizes the control plane, and validate it before applying.
- Compare an installation against the profile it started from by diffing rendered manifests, and read every line of the output.
- Predict what a second `istioctl install` does to settings the new document does not mention.

## Before you start

You should be able to install Istio with `istioctl` and know what `istiod`, a gateway and the injection webhook are — [Module 1 of section 010](../../section-010/module-01/course.md) covers all three, and its Part 4 on reconciliation is the direct prerequisite for Part 3 here.

The playground gives you a single-node `kind` cluster with **`istioctl` 1.30.5** on your PATH and **Istio 1.30.5 already installed with the stock `demo` profile**: `istiod`, an ingress gateway and an egress gateway in `istio-system`, with no overrides of any kind. That unmodified baseline is the point — every difference you can see later is one you caused. All commands run from your normal shell with `kubectl` pointed at the cluster.

## Where this fits

There are two kinds of Istio configuration and confusing them costs real time. **Install-time configuration** is everything in this module: which components exist, how the control plane is sized, and mesh-wide defaults. It is set through `IstioOperator` or Helm values, and changing it means re-running the install. **Runtime configuration** is `VirtualService`, `DestinationRule`, `AuthorizationPolicy` and the rest — ordinary Kubernetes resources you apply and delete at any time, which `istiod` picks up within seconds.

The boundary matters when you are reading a task. "Route 10% of traffic to v2" is runtime and never touches the install. "Turn on access logging for the whole mesh" is install-time. "Turn on access logging for one workload" is runtime again, through a `Telemetry` resource. Deciding which side of that line a requirement sits on is half of getting it right.
