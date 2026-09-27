# In-Place Upgrade Of The Control Plane

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS013/tree/main/sections/section-030/module-03/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/module-03/playground
> astrona destroy ats-013-playground-030-03
> ```

An in-place upgrade is the simple one: there is one control plane, and the new version replaces it. No second revision, no labels to move, no tags to manage. For a small cluster or a patch-level bump it is often the right call, and it is fewer moving parts to get wrong.

What it buys in simplicity it gives back in recovery. There is no old control plane still running to fall back to, so reverting means installing the previous version again and restarting the whole data plane a second time. Knowing when that trade is acceptable — and which checks make it survivable — is what this module is for.

## How this module is organised

1. **[Part 1 — Replacing The Control Plane](./course-01-replacing-the-control-plane.md)** — what "in place" means at the object level, what `istioctl x precheck` inspects and why it must be run with the target binary, and performing the upgrade without discarding your configuration.
2. **[Part 2 — Skew, Completion And The Cost Of Reverting](./course-02-skew-completion-and-reverting.md)** — what version skew actually is, why one minor version is the supported window, the restart that finishes the job, and an honest comparison of the two rollback paths.

## Learning objectives

After this module you can:

- Describe what an in-place upgrade replaces and what it leaves untouched, at the level of Kubernetes objects.
- Run the pre-upgrade checks with the target version's binary and explain why the old binary is the wrong tool for it.
- Upgrade the default control plane in place without losing its configuration.
- Explain what version skew is, why Istio supports one minor version of it, and why that forbids skipping a minor.
- Complete an upgrade by restarting every injected workload, gateways included, and verify the result.
- Compare in-place and canary rollback paths and justify choosing one for a given cluster.

## Before you start

You should know how `istioctl install` renders and reconciles a configuration — [section 010's istioctl module](../../section-010/module-01/course.md) covers it, and its Part 4 on reconciliation matters directly here — and understand that upgrading a control plane leaves running proxies untouched.

The playground gives you a single-node `kind` cluster with:

- **Two `istioctl` binaries**: `istioctl` is **1.29.8**, the version that is installed; `istioctl-1.30.5` is the upgrade target.
- **Istio 1.29.8 installed with the `default` profile** as the single default revision.
- Namespace **`inplace-demo`** with `notification-service-v1` at **two replicas** plus a `tester` pod, all injected. Two replicas matter: during a rolling restart you can watch half the mesh on each version at once.

All commands run from your normal shell with `kubectl` pointed at the cluster.

## Where this fits

This is the second of the two upgrade strategies the ICA curriculum names. The canary module before it runs two control planes and makes rollback a label change; in-place runs one and makes rollback a reinstall. Neither is universally correct, and the exam may ask you to argue the trade-off rather than name a winner.

The Helm upgrade module earlier in this section is mechanically an in-place upgrade too — one control plane, replaced — which is why its skew and restart discussion applies here unchanged. What differs is the tool and the way configuration can be lost: Helm loses it through argument handling, `istioctl` loses it through reconciliation against a document you did not pass.
