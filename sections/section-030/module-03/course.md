# In-Place Upgrade Of The Control Plane

Astronaut, an in-place upgrade is the simple one. There is one mission control, and you replace it in the same building with a newer version. No second revision, no labels to move, no tags to manage. For a small cluster or a patch-level change it is often the right choice, and it has fewer moving parts to get wrong.

What it gives you in simplicity, it takes back in recovery. There is no old mission control still running to fall back to. Going back means installing the previous version again and restarting the whole data plane a second time. This module teaches when that trade is fine, and which checks make it safe.

## Learning objectives

After this module you can:

- Describe what an in-place upgrade replaces and what it leaves alone, at the level of Kubernetes objects.
- Run the pre-upgrade check with the target version's binary, and explain why the old binary is the wrong tool for it.
- Upgrade the default control plane in place without losing its configuration.
- Explain what version skew is, why Istio supports a skew of one minor version, and why that rules out skipping a minor version.
- Finish an upgrade by restarting every workload with a sidecar, gateways included, and check the result.
- Compare the in-place and canary ways of going back, and justify a choice for a given cluster.

## Before you start

Every mission starts with a pre-flight check, astronaut. Make sure you have the knowledge this module expects, and know what is waiting in your playground.

### What you should already know

- **How `istioctl install` works.** It renders a complete blueprint on your machine (an `IstioOperator` document, a profile, and any `--set` flags), then makes the cluster match it. Anything the blueprint does not show gets removed or reset.
- **Upgrades leave proxies behind.** Upgrading the control plane does not touch running proxies. Each one keeps the image it was injected with until its pod is recreated.
- **Kubernetes basics.** Deployments, rolling restarts, and `kubectl exec`.

### What is in your playground

Your playground is a training solar system: one `kind` cluster with:

- **Two `istioctl` binaries.** Plain `istioctl` is **1.29.8**, the installed version. `istioctl-1.30.5` is the upgrade target.
- **Istio 1.29.8, installed with the `default` profile** as the only control plane, the default revision. The profile includes an ingress gateway, `istio-ingressgateway` in `istio-system`.
- The namespace **`inplace-demo`** with `notification-service-v1` at **two replicas**, a `notification-service` Service, and a `tester` pod (your test shuttle), all with sidecars. The two replicas matter: during a rolling restart you can watch half the workload on each version at once.

Every command runs from your normal shell, with `kubectl` already pointing at the cluster.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Work through the parts in this order. The mission comes right after the part it practises.

1. [Replacing The Control Plane](./course-01-replacing-the-control-plane.md): what "in place" means for the objects, what `istioctl x precheck` checks and why you run it with the target binary, and doing the upgrade without throwing away your configuration.
2. [Skew, Completion And The Cost Of Reverting](./course-02-skew-completion-and-reverting.md): what version skew is, why one minor version is the supported window, the restart that finishes the job, and an honest comparison of the two ways back.
   - Mission: [In-Place Upgrade](./labs/lab-01/question.md)
3. [Wrap-Up: Mission Debrief](./course-03-wrap-up.md)

## Why this matters

There are two upgrade strategies. A **canary** upgrade runs two mission controls for a while and makes going back a label change. An **in-place** upgrade runs one and makes going back a reinstall. Neither is always right, and the exam may ask you to argue the trade-off instead of naming a winner.

An in-place upgrade with `istioctl` can lose settings in its own way: a bare `istioctl install` makes the cluster match the default profile, not the cluster you had. Learn to pass the same configuration, to check before and after, and to finish the job with restarts, and an in-place upgrade becomes routine.
