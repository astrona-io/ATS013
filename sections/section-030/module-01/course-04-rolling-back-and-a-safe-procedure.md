# Rolling Back And A Safe Procedure

Every upgrade needs a way back. When an upgrade drops a setting or breaks the mesh, `helm rollback` is the fastest fix Helm offers, but it restores less than most people think. This part shows what `helm rollback` really restores and what it leaves alone. It ends with an upgrade procedure you can write down and follow under pressure.

## What `helm rollback` restores

`helm rollback <release> <revision> -n <ns>` reads an earlier revision from the release history, which is one Secret per revision in the release's namespace. It applies the manifests of that revision again, and records the result as a **new** revision. It restores the release's Kubernetes objects and the values that produced them. So for `istiod`, both the control plane image and the `meshConfig` (the mesh-wide settings in the `istio` ConfigMap) go back.

That is the whole job of the command, and three things fall outside it:

- **It does not restart application pods.** Their sidecar proxies keep running whatever image and resource requests they were injected with. After you roll the control plane back, you may need another `kubectl rollout restart` to bring the data plane with it. That is the same step as in the upgrade, in the other direction.
- **It does not touch other releases.** Roll `istiod` back to 1.29.8 while `istio-base` stays at 1.30.5, and you get a mix nobody tested. A rollback of one release is not a rollback of the install.
- **It does not undo anything outside the release.** That includes the CRDs installed by `base`, and objects you created by hand.

You can see all of this on your playground. This step assumes the playground's `istiod` release is on chart 1.30.5 with `REGISTRY_ONLY` set, so revision 1 is the original 1.29.8 install. If you have not upgraded yet, run these commands first:

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

If your machine runs Helm 4, add `--force-conflicts` to the `helm rollback` command. Without it, the rollback stops with `Error: conflict occurred while applying object /istio-validator-istio-system`: Helm 4 applies objects with server-side apply, and `istiod` itself owns the `failurePolicy` field of its validating webhook, so Helm 4 must be told to take that field back. Helm 3 does not need that flag.

The output looks like this with Helm 4 (shortened: the `DESCRIPTION` column of the history is cut, and the error of the failed try is left out). This run had two failed rollback tries without `--force-conflicts`, one earlier in the playground and one here; each one is a revision, so `istiod` ends at revision 8, and your numbers can be lower:

```text
3       	Sat Oct 10 02:26:52 2026	failed    	istiod-1.29.8	1.29.8     	Rollback "istiod" failed: conflict occurred while applying object /istio-validator-istio-system admissionregistration.k8s.io/v1, 
4       	Sat Oct 10 02:26:53 2026	superseded	istiod-1.29.8	1.29.8     	Rollback to 1                                                                                                                    
5       	Sat Oct 10 02:27:06 2026	superseded	istiod-1.30.5	1.30.5     	Upgrade complete                                                                                                                 
6       	Sat Oct 10 02:28:37 2026	deployed  	istiod-1.30.5	1.30.5     	Upgrade complete                                                                                                                 
Rollback was a success! Happy Helming!
outboundTrafficPolicy:
  mode: ALLOW_ANY
rootNamespace: istio-system
docker.io/istio/pilot:1.29.8
NAME      	NAMESPACE   	REVISION	UPDATED                              	STATUS  	CHART        	APP VERSION
istio-base	istio-system	2       	2026-10-10 02:28:35.999143 +0200 CEST	deployed	base-1.30.5  	1.30.5     
istiod    	istio-system	8       	2026-10-10 02:29:48.352039 +0200 CEST	deployed	istiod-1.29.8	1.29.8     
```

The mesh setting is back to its revision 1 value, and the control plane image went back with it. Now look at the last two lines: `istio-base` is still on 1.30.5 while `istiod` is back on 1.29.8. That is "not a rollback of the install", visible in two columns. The revision number of `istiod` depends on how many times you upgraded it before, and every failed try counts as a revision too.

## A procedure worth writing down

The rollback shows how much depends on the steps around a Helm command. Put the pieces together, and an Istio upgrade with Helm is six steps:

1. **Check that the values file matches reality.** Compare `helm get values` with your saved file. If they differ, find out why before anything else.
2. **Do a dry run and read the values.** `helm upgrade ... -f <file> --dry-run --debug` prints them without touching the cluster.
3. **Upgrade in order.** `base`, `istiod`, then the gateways, each pinned with `--version` and given its own `-f`.
4. **Check that the settings survived.** Read the `istio` ConfigMap and any setting that matters to you.
5. **Restart the data plane.** Every namespace in the mesh, plus the gateways.
6. **Check for a single data plane version.** Run `istioctl version`, then `istioctl proxy-status` if the versions disagree.

Steps 4 and 6 catch the two failures that matter most: lost settings and old proxies. They are also the two steps people leave out.

## Before an upgrade in a real cluster

A playground lets you start over. A production cluster does not, so plan for four more things before you start.

First, count the restarts. Finishing the upgrade means replacing every pod in the mesh. Check each `PodDisruptionBudget`, the Kubernetes object that limits how many pods of an application may be down at once. Decide whether the restarts need a maintenance window or can run in the background, and restart the least important namespaces first. Then a problem shows up while most of the mesh still runs the old proxy.

Second, protect the release history. Rollback and value recovery both depend on the release Secrets. Back up the namespace, and save the values file in version control so the cluster is not the only copy.

Third, watch certificates, not just pods. `istiod` is also the certificate authority of the mesh: it signs the certificates that sidecar proxies use for mutual TLS (mTLS, where both sides of a connection prove who they are). A workload that cannot get a fresh certificate keeps working until its current one expires. Then it fails in a way that looks unrelated to the upgrade, so a quiet mesh right after the upgrade does not prove a healthy one.

Fourth, remember that a Helm rollback is not an Istio rollback. Reverting the control plane leaves the data plane where it was, and moving the workloads back means a second full round of restarts. A canary upgrade avoids this: it runs a second `istiod` next to the old one, so going back is a change of namespace label.

You now know that `helm rollback` applies an older revision of one release as a new revision, and that it does not restart pods, touch the other releases or undo anything outside the release. You also have a six-step procedure whose checks catch lost settings and old proxies. The open question for a real cluster is how to plan the restarts, the history and the certificates around those steps.

## Common pitfalls

> [!WARNING]
> **Treating `helm rollback` as a full undo.** It restores one release's objects. It does not restore the pods created from them, and it does not touch the other releases.
>
> **Rolling back `istiod` and forgetting the data plane.** The sidecars keep the image and resource requests they were injected with. Restart the workloads if they must follow the control plane back.
>
> **Rolling back one release and calling the install reverted.** Check `helm ls -A`: `istio-base` and the gateway keep their own versions.
>
> **Skipping the dry run.** Reading the computed values takes seconds and catches a lost set of values before it does damage.

## Your mission: Roll Back A Helm Release Of istiod Lab

You can now read a release history, roll one release back to a good revision, and bring the data plane in line afterwards. The lab asks you to undo a `helm upgrade` of `istiod` that dropped every setting from the install, by rolling the release back, and to restart the workload so its sidecar proxy gets the original resource requests again.

The lab runs on its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-013-playground-030-01
```

Then start the lab. The task is on the next page; solve it on your own first:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/module-01/labs/lab-02
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-01/labs/lab-02
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-013-lab-030-01-02
astrona start ats-013-playground-030-01
```
