# In-Place Upgrade Of The Control Plane

`istiod` is Istio's control plane. It turns Istio resources into proxy configuration and sends it, together with certificates, to every sidecar proxy in the mesh. An in-place upgrade replaces that one `istiod` with a newer version, under the same names. There is no second control plane, no namespace label to move and no revision tag to manage. For a small cluster or a patch release it is often the right choice, because it has fewer parts that can go wrong.

The price of that simplicity is paid when you need to go back. No old control plane keeps running next to the new one. Going back means installing the previous version again and restarting the whole data plane a second time. This module shows when that trade is acceptable, and which checks make an in-place upgrade safe.

## Learning objectives

After this module you can:

- Describe what an in-place upgrade replaces and what it leaves alone, at the level of Kubernetes objects.
- Run the pre-upgrade check with the target version's `istioctl` binary, and explain why the old binary is the wrong tool for it.
- Upgrade the default control plane in place without losing its configuration.
- Explain what version skew is, why Istio supports a skew of one minor version, and why that rules out skipping a minor version.
- Finish an upgrade by restarting every workload with a sidecar proxy, gateways included, and check the result.
- Compare going back from an in-place upgrade with going back from a canary upgrade, and choose one for a given cluster.

## Before you start

This module expects you to know how Istio is installed and what happens to running proxies when the control plane changes.

### What you should already know

- **How `istioctl install` works.** It renders a complete set of Kubernetes objects on your machine from an `IstioOperator` document, a profile and any `--set` flags. Then it makes the cluster match that set. Anything the new set does not contain is removed or reset.
- **Upgrades leave proxies behind.** Upgrading the control plane does not touch running proxies. Each proxy keeps the image it was injected with until its pod is created again.
- **Kubernetes basics.** Deployments, rolling restarts and `kubectl exec`.

### What is in your playground

The playground is one single-node `kind` cluster with:

- **Two `istioctl` binaries.** Plain `istioctl` is **1.29.8**, the installed version. `istioctl-1.30.5` is the upgrade target.
- **Istio 1.29.8, installed with the `default` profile** as the only control plane, the default revision. The profile includes an ingress gateway, `istio-ingressgateway` in `istio-system`.
- **The namespace `inplace-demo`** with the Deployment `notification-service-v1` at **two replicas**, a `notification-service` Service and a `tester` Deployment, all with sidecar proxies. The two replicas let you see, during a rolling restart, one pod on each version at the same time.

You run every command from your normal shell, and `kubectl` already points at the cluster.

Start your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Read the parts in this order:

1. **Replacing The Control Plane:** what "in place" means for the objects in the cluster, what `istioctl x precheck` checks and why you run it with the target binary, and how to upgrade without throwing away your configuration.
2. **Version Skew And Finishing The Upgrade:** what version skew is, why one minor version is the supported gap, and the restarts that bring every proxy, the gateway included, onto the new version. The graded lab "In-Place Upgrade" follows this part.
3. **The Cost Of Going Back:** how going back from an in-place upgrade compares with a canary upgrade, when in-place is still the right choice, and what to plan before an upgrade on a real cluster.

A summary closes the module.
