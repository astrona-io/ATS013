# The Cost Of Going Back

An upgrade plan is only complete when it says how to go back. For an in-place upgrade, going back is much more expensive than going forward, and that difference decides when the method is a good fit. The exam expects you to argue the trade-off between an in-place upgrade and a canary upgrade, not to name a favourite. This part compares the two ways back, says when in-place is still the right choice, and lists what to plan before an in-place upgrade on a real cluster.

## The two ways back side by side

An in-place upgrade replaces the one `istiod` Deployment under the same name. A canary upgrade installs the new version as a second revision, a second control plane with its own suffixed names, and moves namespaces to it by changing the namespace label or a revision tag. A **revision tag** is a stable name, such as `prod`, that points at one revision; namespaces use the tag, so you can move them all by moving the tag. The table compares the two methods:

| | In-place | Canary |
| --- | --- | --- |
| Control planes running | One | Two, while the move lasts |
| Moving a workload forward | Restart it | Relabel or move a tag, then restart |
| **Going back** | Reinstall the old version, then restart everything again | Move the label or tag back, then restart |
| Going back under pressure | A full data plane restart, during an incident | One command, then restarts at your own pace |
| Damage from a bad version | The whole mesh at once | One namespace until you widen it |
| Resource cost | Lower | Two control planes |
| Objects to reason about | One set | Two sets, with suffixes |

Going back from an in-place upgrade is not just "more commands". It is a second restart of every pod in the mesh, done while something is already going wrong, on a cluster whose control plane you are changing at the same time. Going forward is cheap and going back is expensive. That imbalance is the whole argument against in-place on a large production mesh.

Reinstalling the old control plane also does not move the proxies back. Every pod keeps the new proxy image it received until you restart it again, so the data plane runs ahead of the control plane until the second restart is done.

## When in-place is still the right choice

The imbalance does not make in-place wrong. It makes it a fit for clusters where going back is unlikely or cheap. In-place stays reasonable for a patch release (1.30.4 to 1.30.5, where you are unlikely to need to go back), for a development cluster, or for a mesh small enough that a full restart takes minutes, not hours. "Canary in production" is a good default, not a law.

Whichever method you choose, have the old configuration before you start. For an in-place upgrade, going back means "install the previous version with the previous configuration". If that configuration exists only in the cluster you are about to change, you have no plan to go back. Export it first: use the `IstioOperator` file if you have one. If you do not, rebuild it from the `istio` ConfigMap and the Deployments in `istio-system`.

## Planning an in-place upgrade on a real cluster

A playground forgives every mistake. A production cluster does not, so plan the following points before you start. Each one comes from a step that is easy to get right on a small cluster and expensive to get wrong on a large one.

### Count the restarts

Finishing the upgrade means replacing every pod in the mesh. Count those pods. Check each `PodDisruptionBudget`, the Kubernetes object that limits how many pods of an application may be down at the same time. Then decide whether the restarts need a maintenance window or can run in the background. This number usually decides between in-place and canary more than any theory.

### Restart in a chosen order

Restart the least important namespaces first, so a problem shows up while most of the mesh still runs the old proxy. Restart the gateways last, once the Services behind them are known to work.

### Check after the upgrade, not only before

Run `istioctl analyze` after the upgrade. `istioctl x precheck` asked whether the cluster was ready for the new version. `istioctl analyze` asks whether the configuration now in the cluster is consistent, and it reports fields the new release has deprecated.

### Watch certificates, not only pods

`istiod` is also the certificate authority that signs each proxy's certificate. A workload that cannot get a new certificate keeps working until its current certificate expires. Then it fails in a way that looks unrelated to the upgrade, hours later.

### Run two istiod replicas

While a single `istiod` pod restarts, there is a short time with no ready control plane, and the API server rejects new pods in namespaces with injection. A second `istiod` replica removes that gap. It costs little, and it belongs in place before the upgrade, not during it.

You now know that going back from an in-place upgrade means reinstalling the old version and restarting the whole data plane again, while a canary upgrade only moves a label or a tag back. You also know when in-place is still a good fit, and what to count, order and check before you run it on a real cluster. The open question for any upgrade is the same one: do you have the old configuration saved before you start?

## Common pitfalls

> [!WARNING]
> **Assuming going back is symmetric.** Reinstalling the old control plane leaves every pod on the new proxy image until you restart them all again.
>
> **Starting without the old configuration.** If it exists only in the cluster you are changing, you cannot go back. Export it first.
>
> **Treating a quiet mesh as a healthy one.** Certificate renewal failures show up hours after the upgrade, not straight away.
>
> **Choosing a method by habit.** Count the pods to restart and weigh the cost of going back. A patch release on a small cluster and a minor release on a large production mesh need different answers.
