# Rolling Back And A Safe Procedure

Every upgrade needs a way back. This part shows what `helm rollback` really restores, and what it leaves alone. It ends with an upgrade procedure you can write down and follow under pressure.

In space terms, `helm rollback` rebuilds a kit from an older page of its logbook. The logbook is the release history: one Secret per revision, kept in the release's namespace.

## What `helm rollback` restores

Start with what the command does, then with the three things it does not do.

### What it does

`helm rollback <release> <revision> -n <ns>` applies the manifests of an earlier revision again, and records the result as a **new** revision. It restores the release's Kubernetes objects and the values that produced them. So for `istiod`, both the control plane image and the `meshConfig` (the fleet's standing orders) go back.

### What it does not do

- **It does not restart application pods.** Their sidecars keep running whatever image they were injected with. After you roll the control plane back, you may need another rollout restart to bring the data plane with it. That is the same step as in the upgrade, in the other direction.
- **It does not touch other releases.** Roll `istiod` back to 1.29.8 while `istio-base` stays at 1.30.5, and you get a mix nobody tested. A rollback of one release is not a rollback of the install.
- **It does not undo anything outside the release.** That includes the CRDs installed by `base`, and objects you created by hand.

### See a mesh setting revert through a rollback

This step assumes the playground's `istiod` release is on chart 1.30.5 with `REGISTRY_ONLY` set, so revision 1 is the original 1.29.8 install. If you have not upgraded yet, run these first:

<!-- astrona:playground:renew -->

```sh
helm get values istiod -n istio-system --revision 1 | tail -n +2 > istiod-values.yaml
sed -i.bak 's/mode: ALLOW_ANY/mode: REGISTRY_ONLY/' istiod-values.yaml && rm -f istiod-values.yaml.bak
helm upgrade istio-base istio/base -n istio-system --version 1.30.5 --wait
helm upgrade istiod istio/istiod -n istio-system --version 1.30.5 -f istiod-values.yaml --wait
```

Now read the history, roll `istiod` back to revision 1, and check what changed:

```sh
helm history istiod -n istio-system | tail -4
helm rollback istiod 1 -n istio-system --wait
kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep -A2 outboundTrafficPolicy
kubectl -n istio-system get deploy istiod -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
helm ls -n istio-system
```

Expect something like:

```text
Rollback was a success! Happy Helming!

outboundTrafficPolicy:
  mode: ALLOW_ANY

docker.io/istio/pilot:1.29.8

NAME         NAMESPACE      REVISION  STATUS    CHART          APP VERSION
istio-base   istio-system   2         deployed  base-1.30.5    1.30.5
istiod       istio-system   6         deployed  istiod-1.29.8  1.29.8
```

The mesh setting is back to its revision 1 value, and the control plane image went back with it. Now look at the last two lines: `istio-base` is still on 1.30.5 while `istiod` is back on 1.29.8. That is "not a rollback of the install", visible in two columns. The revision number of `istiod` depends on how many times you upgraded it before.

## A procedure worth writing down

Put the pieces together, and an Istio upgrade with Helm is six steps:

1. **Check that the values file matches reality.** Compare `helm get values` with your saved file. If they differ, find out why before anything else.
2. **Do a dry run and read the computed values.** `helm upgrade ... -f <file> --dry-run --debug` prints them without touching the cluster.
3. **Upgrade in order.** `base`, `istiod`, then the gateways, each pinned with `--version` and given its own `-f`.
4. **Check that the settings survived.** Read the `istio` ConfigMap and any setting that matters to you.
5. **Restart the data plane.** Every namespace in the mesh, plus the gateways.
6. **Check for a single data plane version.** Run `istioctl version`, then `istioctl proxy-status` if the versions disagree.

Steps 4 and 6 catch the two failures that matter most: lost settings and old proxies. They are also the two steps people leave out.

## Before an upgrade in a real cluster

A playground forgives everything. A production cluster does not, so plan for these four things before you start.

### Count the restarts

Finishing the upgrade means replacing every pod in the mesh. Check each `PodDisruptionBudget` (the rule that limits how many pods of an app may be down at once). Decide whether this is a maintenance window or a background task. Restart the least important namespaces first, so a problem shows up while most of the mesh still runs the old proxy.

### Protect the release history

Rollback and value recovery both live in the release Secrets. Back up the namespace, and save the values file in version control so the cluster is not the only copy.

### Watch certificates, not just pods

`istiod` is also the certificate authority: mission control's badge office. A workload that cannot get a fresh certificate keeps working until its current one expires. Then it fails in a way that looks unrelated to the upgrade. A quiet mesh right after the upgrade does not prove a healthy one.

### A Helm rollback is not an Istio rollback

Reverting the control plane leaves the data plane where it was. Moving the workloads back means a second full round of restarts. A canary upgrade avoids this: the old mission control keeps running, so going back is a label change.

Rollback only takes back what one release owns.

## Common pitfalls

> [!WARNING]
> **Treating `helm rollback` as a full undo.** It restores one release's objects. It does not restore the pods created from them, and it does not touch the sibling releases.
>
> **Rolling back `istiod` and forgetting the data plane.** The sidecars keep the image they were injected with. Restart the workloads if they must follow the control plane back.
>
> **Rolling back one release and calling the install reverted.** Check `helm ls -A`: `istio-base` and the gateway keep their own versions.
>
> **Skipping the dry run.** Reading the computed values takes seconds and catches a missing `-f` before it does damage.

## Your mission: Upgrade And Reconfigure Istio With Helm

You can now recover a release's values, upgrade the three releases in order, and finish the job by restarting the data plane. Now prove it in a graded mission: upgrade a Helm-installed Istio from 1.29.8 to 1.30.5 without losing a single setting, change one mesh option on the way, and leave no version skew behind.

The mission runs in its own training solar system, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-013-playground-030-01
```

Then start the mission:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/module-01/labs/lab-01
```

Read the task in [`question.md`](./labs/lab-01/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-01/labs/lab-01
```

When the mission is done, remove it and wake your playground up again:

```sh
astrona destroy ats-013-lab-030-01
astrona start ats-013-playground-030-01
```
