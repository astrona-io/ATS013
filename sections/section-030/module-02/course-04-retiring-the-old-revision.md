# Retiring The Old Revision

Once every workload has moved and you trust the new control plane, the old one only costs resources. Removing it is the last step of a canary upgrade, and it is the one step that is hard to undo. This part shows how to remove the old revision safely: in which order, with which command, and how to check first that nothing still depends on it. It ends with the gateways, which the steps so far have not moved.

## The order is not negotiable

`istioctl uninstall --revision <name>` removes one named revision. It leaves the rest of the installation alone: the other revision and the shared CRDs (Custom Resource Definitions, which add Istio's object kinds to the Kubernetes API).

The rule is short: **restart every workload onto the new revision first, then uninstall the old one.**

### What happens if you reverse the order

The order matters because a pod whose control plane has been removed does not fail at once. That delay is what makes the wrong order dangerous. The sidecar proxy keeps running on the configuration it last received from `istiod`. What it loses is everything that `istiod` keeps sending over time:

- no configuration updates;
- no endpoint updates as other pods start and stop;
- no certificate renewal when its current workload certificate expires.

The workload certificate is the identity the proxy uses for mTLS (mutual TLS, where both sides of a connection prove their identity with a certificate). When it expires and nobody renews it, the proxy can no longer open mTLS connections. The failure arrives hours later and does not look like its cause.

### Name the revision, never purge

`istioctl uninstall --purge` removes **every** revision and all cluster-wide Istio resources, CRDs included. That takes the new control plane down along with the old one. To remove one control plane, always name it: `istioctl uninstall --revision default -y`.

## Check for workloads left behind first

Knowing the right order is only useful if you can prove that the move is complete. Before you remove anything, check that no workload still depends on the old control plane. `istioctl proxy-status` asks one control plane for the proxies connected to it: the default revision, unless you pass `--revision`. So plain `istioctl proxy-status` lists exactly the proxies that still depend on the old control plane. List them, then any namespace still labelled for the old control plane, then the proxies of the new revision:

<!-- astrona:playground:renew -->

```sh
istioctl proxy-status
kubectl get ns -l istio-injection=enabled
kubectl get ns -l istio.io/rev=default
istioctl-1.30.5 proxy-status --revision 1-30-5
```

The output looks like this:

```text
NAME                                                   CLUSTER        ISTIOD                      VERSION     SUBSCRIBED TYPES
istio-egressgateway-7b5fc4675c-z5cgw.istio-system      Kubernetes     istiod-68b5bc79c8-27k2j     1.29.8      3 (CDS,LDS,EDS)
istio-ingressgateway-7f57d9869c-7fnn2.istio-system     Kubernetes     istiod-68b5bc79c8-27k2j     1.29.8      3 (CDS,LDS,EDS)
No resources found
No resources found
NAME                                                     CLUSTER        ISTIOD                            VERSION     SUBSCRIBED TYPES
notification-service-v1-656989c9f4-rxs85.canary-demo     Kubernetes     istiod-1-30-5-67fd8d4b8-6tmgd     1.30.5      4 (CDS,LDS,EDS,RDS)
```

The workload is gone from the old control plane's list and shows up under `istiod-1-30-5`, and no namespace is still labelled for the old one. Check both kinds of evidence. `proxy-status` finds running pods, and the namespace queries find namespaces whose pods are scaled to zero right now.

Two proxies are still on the old control plane: the egress and ingress gateways. They are the reason this check is not yet the green light for `istioctl uninstall --revision default -y`. The next section is about them.

If `canary-demo` is still on the old control plane in your playground, move it first. Label it `istio.io/rev=prod` (or `istio.io/rev=1-30-5`), remove `istio-injection`, and restart `notification-service-v1`.

## Moving the gateways

Even when every sidecar has moved, the gateways have not. A gateway, such as the ingress gateway that receives traffic from outside the cluster, is a standalone Envoy Deployment, not a sidecar. No namespace label picks a control plane for it. Its control plane is fixed in its pod spec when it is installed. In the `demo` profile, the gateways belong to the default revision, so they need their own plan.

There are two common approaches:

- **Install a gateway for the new revision** next to the existing one, move the traffic at the load balancer or DNS layer, then remove the old gateway. This is the safest way, and it costs a second public address for a while.
- **Reinstall the gateway against the new revision in place**, and accept a short interruption while the Deployment replaces its pods.

Either way, do it as a separate step with its own checks. The gateway is the component whose failure users outside the cluster see at once.

## Before you retire in a real cluster

The commands are the same in production, but the timing is different. Two habits keep the rollback cheap until you are sure you no longer need it.

### Space out the restarts, but finish them

The tag change takes effect at once, and you can spread the restarts over days. But two control planes cost resources and attention, and a half-moved mesh is harder to reason about than either end state. Finish the move.

### Keep the old revision until the new one has seen real load

Going back is cheap only because the old control plane is still running. Deleting it the same afternoon turns a two-command rollback into a reinstall.

You now know to retire the old revision last: after `istioctl proxy-status` and the namespace labels show that every workload uses the new one, and only with `istioctl uninstall --revision <name>`. You also know that gateways move as their own step. The open question for a real cluster is only timing: how long the new revision must run under real load before you trust it.

## Common pitfalls

> [!WARNING]
> **Uninstalling the old revision before restarting workloads.** Those pods lose configuration updates and certificate renewal, and fail later in ways that look unrelated.
>
> **`istioctl uninstall --purge` during a canary upgrade.** It removes every revision, including the new one, and the shared CRDs with them.
>
> **Checking only `istioctl proxy-status`.** A namespace scaled to zero has no proxies to list. Check the namespace labels too.
>
> **Assuming the canary upgrade moved the gateways.** Gateways are standalone Deployments. Move them as their own step, with their own checks.

## Your mission: Retire The Old Control Plane Revision Lab

You can now check that no workload still depends on the old control plane, and remove that control plane by its revision name. The lab asks you to find a namespace that was left on the old control plane, move it onto the `prod` tag, and then retire the default revision so that only the 1.30.5 control plane remains and traffic still flows.

The lab runs on its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-013-playground-030-02
```

Then start the lab. The task is on the next page; solve it on your own first:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/module-02/labs/lab-02
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-02/labs/lab-02
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-013-lab-030-02-02
astrona start ats-013-playground-030-02
```
