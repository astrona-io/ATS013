# Retiring The Old Revision

Once every workload has moved and you trust the new control plane, the old one is dead weight. This part shows how to remove it safely: in which order, with which command, and how to check that nothing still depends on it. It ends with the gateways, which nothing so far has moved.

In space terms: you are closing the old mission control. Do it only after every ship reports to the new one.

## The order is not negotiable

`istioctl uninstall --revision <name>` removes one named revision. It leaves the rest of the install alone: the shared Custom Resource Definitions (CRDs, the forms that teach the cluster Istio's object kinds) and the other revision.

The rule: **restart every workload onto the new revision first, then uninstall the old one.**

### What happens if you reverse it

A pod whose control plane has been removed does not fail at once. That is what makes the wrong order dangerous. The pod keeps running on the configuration its proxy last received. What it loses is everything *ongoing*:

- no configuration updates;
- no endpoint updates as other pods come and go;
- no certificate renewal when its current workload certificate expires.

In space terms, the ship keeps flying on its last orders, but nobody radios new ones and nobody renews its ID badge. The failure arrives hours later and looks nothing like its cause.

### Name the revision, never purge

`istioctl uninstall --purge` removes **every** revision and all cluster-wide Istio resources, CRDs included. That takes the new control plane down along with the old one. To remove one control plane, always name it: `istioctl uninstall --revision default -y`.

## Check for stragglers first

Before you remove anything, prove that no workload still depends on the old control plane.

### See it in your playground

List every proxy, then any namespace still labelled for the old control plane:

<!-- astrona:playground:renew -->

```sh
istioctl proxy-status
kubectl get ns -l istio-injection=enabled
kubectl get ns -l istio.io/rev=default
```

Expect something like:

```text
NAME                                     CLUSTER      CDS      LDS      EDS      RDS      ISTIOD
notification-service-v1-...canary-demo   Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED   istiod-1-30-5-...

No resources found
No resources found
```

This is the evidence you want before you run `istioctl uninstall --revision default -y`: every entry in `proxy-status` names the *new* control plane pod, and no namespace is still labelled for the old one. Check both. `proxy-status` catches running pods. The namespace queries catch namespaces whose pods happen to be scaled to zero right now.

If `canary-demo` is still on the old control plane in your playground, move it first: label it `istio.io/rev=prod` (or `istio.io/rev=1-30-5`), remove `istio-injection`, and restart `notification-service-v1`.

## Moving the gateways

Gateways need their own plan, because nothing in a canary moves them. An ingress gateway (the spaceport arrival gate) is a standalone Envoy Deployment, not a sidecar. No namespace label picks a control plane for it. Its control plane is fixed in its pod spec when it is installed.

There are two common approaches:

- **Install a revisioned gateway** next to the existing one, shift traffic at the load balancer or DNS layer, then remove the old one. This is the safest way, and it costs a second public address for a while.
- **Reinstall the gateway against the new revision in place**, and accept a short interruption while the Deployment rolls.

Either way, do it as a separate step with its own checks. The gateway is the piece whose failure is visible from outside the cluster at once.

## Before you retire in a real cluster

Two habits keep the rollback cheap until you really do not need it.

### Pace the restarts, but finish them

The tag change is instant, and the restarts can be spread over days. But two control planes cost resources and attention, and a half-moved mesh is harder to reason about than either end state. Finish the move.

### Keep the old revision until the new one has seen real load

Going back is cheap exactly because the old control plane is still running. Deleting it the same afternoon turns a two-command rollback into a reinstall.

Retire the old mission control last: after every ship has relaunched under the new one, and only by its name.

## Common pitfalls

> [!WARNING]
> **Uninstalling the old revision before restarting workloads.** Those pods lose configuration updates and certificate renewal, and fail later in ways that look unrelated.
>
> **`istioctl uninstall --purge` during a canary.** It removes every revision, including the new one, and the shared CRDs with them.
>
> **Checking only `proxy-status`.** A namespace scaled to zero has no proxies to list. Check the namespace labels too.
>
> **Assuming the canary moved the gateways.** Gateways are standalone Deployments. Move them as their own step, with their own checks.
