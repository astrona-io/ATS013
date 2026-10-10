# Upgrading In Order And Finishing The Job

With a complete values file in hand, the upgrade itself is three commands in a fixed order. Then comes a fourth step that most people skip, because the mesh keeps working without it. This part covers the order of the three Helm releases, and the restart that really finishes an Istio upgrade.

The values file used here is `istiod-values.yaml`, rebuilt from revision 1 of the `istiod` release with `helm get values istiod -n istio-system --revision 1 | tail -n +2 > istiod-values.yaml`. If it is not in your working folder, run that command first.

## The order, and why it holds

The upgrade order is `base`, then `istiod`, then each gateway. It is the same order as the install, for a related but different reason.

At install time the rule is absolute. The `istio/base` chart installs the CRDs (Custom Resource Definitions), which add Istio's object kinds, such as `VirtualService`, to the Kubernetes API. The `istiod` chart creates objects of those kinds, so it cannot go first.

At upgrade time the CRDs already exist, so a wrong order often *seems* to work. The rule is now about the schema of those CRDs. A newer `istiod` may set fields on Istio objects that only the newer CRDs accept. If you upgrade `istiod` first, it may write or check configuration that the old CRDs reject. Sometimes that fails at once. Sometimes it fails only when someone next applies a certain object, which makes the wrong order worse than a clean failure.

The order also says which release gets which values file. Only `istiod` takes `-f istiod-values.yaml`. In this playground, `base` and the gateway were installed without a values file, so chart defaults are the right desired state for them. That is a fact about this install, not a general rule: whatever file a release was installed with is the file you upgrade it with.

## Make the change in the file

The upgrade should also switch the mesh-wide outbound traffic policy from `ALLOW_ANY` to `REGISTRY_ONLY`. With `REGISTRY_ONLY`, the sidecar proxies only send traffic to hosts that `istiod` knows about. Make that change by editing the values file, not by adding a `--set` flag, so that the file stays complete.

<!-- astrona:playground:renew -->

Edit the file in place:

```sh
sed -i.bak 's/mode: ALLOW_ANY/mode: REGISTRY_ONLY/' istiod-values.yaml && rm -f istiod-values.yaml.bak
```

`-i` takes no argument on GNU sed but needs one on the BSD sed that ships with macOS. `-i.bak` works on both: it edits in place and leaves a backup, which the `rm` then removes.

## Upgrade all three releases

The file now holds every old setting plus the one change. Upgrade `base`, `istiod` and the gateway in that order, then read the releases and the mesh settings:

```sh
helm upgrade istio-base istio/base -n istio-system --version 1.30.5 --wait
helm upgrade istiod istio/istiod -n istio-system --version 1.30.5 -f istiod-values.yaml --wait
helm upgrade istio-ingressgateway istio/gateway -n istio-ingress --version 1.30.5 --wait
helm ls -A
kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep -A2 -E 'accessLogFile|outboundTrafficPolicy'
```

The output looks like this (shortened: each `helm upgrade` also prints its status and release notes):

```text
Release "istio-base" has been upgraded. Happy Helming!
Release "istiod" has been upgraded. Happy Helming!
Release "istio-ingressgateway" has been upgraded. Happy Helming!
NAME                	NAMESPACE    	REVISION	UPDATED                              	STATUS  	CHART         	APP VERSION
istio-base          	istio-system 	2       	2026-10-10 02:28:35.999143 +0200 CEST	deployed	base-1.30.5   	1.30.5     
istio-ingressgateway	istio-ingress	2       	2026-10-10 02:28:37.676204 +0200 CEST	deployed	gateway-1.30.5	1.30.5     
istiod              	istio-system 	6       	2026-10-10 02:28:37.128867 +0200 CEST	deployed	istiod-1.30.5 	1.30.5     
accessLogFile: /dev/stdout
defaultConfig:
  discoveryAddress: istiod.istio-system.svc:15012
--
outboundTrafficPolicy:
  mode: REGISTRY_ONLY
rootNamespace: istio-system
```

The new chart version is on all three releases, the old settings are intact, and the one change you wanted is there. `istiod` shows a higher revision than the others because each earlier experiment with it in this playground added a revision; the output above comes from a run where one rollback failed first, which adds a revision too, so your number can be one lower. The history records what happened, not what you meant.

## The data plane has not moved

Helm says `deployed` for all three releases, but the upgrade is not finished. Upgrading `istiod` replaces the control plane pod. It does not touch your application pods.

Each application pod still runs the sidecar image it was **injected with**. The injection webhook is a mutating admission webhook that `istiod` serves: when a pod is created, the Kubernetes API server calls it, and `istiod` adds the `istio-proxy` container with the proxy image of the current version. That image is written into the stored pod spec, and a control plane upgrade never rewrites a stored pod spec.

The result is **version skew**: the control plane runs a newer version than the proxies it sends configuration to. Istio supports a skew of one minor version. That is what makes a rolling upgrade possible, because in a large mesh there is no single moment when every proxy changes together. Two commands make the skew visible. `istioctl version` splits `data plane version` into groups when proxies disagree, and `istioctl proxy-status` lists every proxy, so you can see *which* ones are behind.

Read the versions, then the image of the application's sidecar proxy. Istio runs `istio-proxy` as a native sidecar, an init container with `restartPolicy: Always`, so the image is in `.spec.initContainers`:

```sh
istioctl version
kubectl -n default get pod -l app=notification-service \
  -o jsonpath='{.items[0].spec.initContainers[?(@.name=="istio-proxy")].image}{"\n"}'
```

The output looks like this:

```text
client version: 1.29.8
control plane version: 1.30.5
data plane version: 1.29.8 (1 proxies), 1.30.5 (1 proxies)
docker.io/istio/proxyv2:1.29.8
```

The screen gives three answers. Your `istioctl` binary is old, the control plane is new, and the data plane is split. The `notification-service` proxy is still `1.29.8`. The gateway proxy is already `1.30.5`, because `helm upgrade` of the gateway release changed the `helm.sh/chart` and `app.kubernetes.io/version` labels on its pod template, and that change made the Deployment controller replace the gateway pod. If you run the command while that rollout is still going, you see three proxies for a moment. Only the old application proxy is a real problem, and only a restart fixes it. The first does not matter much: `istioctl` is a client, and an old client talking to a new control plane just gives slightly less useful diagnostics.

## Finishing the upgrade

A proxy gets a new image the only way any container does: Kubernetes replaces the pod. `kubectl rollout restart deployment` asks the Deployment controller to do that, a few pods at a time. Each new pod passes through the injection webhook again and gets the new proxy image.

Gateways count too. An ingress gateway is an Envoy workload with its own Deployment, and the control plane upgrade does not restart it. Here the gateway's own `helm upgrade` already replaced its pod, but a gateway that is not upgraded with its own chart keeps its old proxy until you restart it. It is also the workload whose old version is most visible from outside the cluster.

Restart the application and the gateway, wait for the application, and read the versions again:

```sh
kubectl -n default rollout restart deployment
kubectl -n istio-ingress rollout restart deployment istio-ingressgateway
kubectl -n default rollout status deployment notification-service --timeout=180s
istioctl version
```

The output looks like this (shortened: the `restarted` and `rollout status` lines are left out):

```text
client version: 1.29.8
control plane version: 1.30.5
data plane version: 1.30.5 (2 proxies)
```

If it says `3 proxies`, the old gateway pod is still shutting down; run `istioctl version` again a few seconds later.

A single `data plane version` that matches the control plane means the upgrade is complete. If two versions are still listed, something was not restarted. `istioctl proxy-status` names the workloads, and the answer is usually a Deployment in a namespace nobody remembered was in the mesh.

To find those namespaces before they surprise you, list every namespace with the injection label:

```sh
kubectl get ns -l istio-injection=enabled
```

```text
NAME      STATUS   AGE
default   Active   3m26s
```

Every namespace in that list needs a restart. A workload that joined the mesh through a label on the pod instead of the namespace does not show up here, so `istioctl proxy-status` stays the full list.

You now know that the three releases go `base`, `istiod`, gateway, each with the values file it was installed with, and that `helm upgrade` leaves every running sidecar on its old image. `istioctl version` shows the skew, and `kubectl rollout restart` on every meshed namespace and on the gateway closes it. The open question is how to go back when an upgrade goes wrong, and what `helm rollback` leaves behind.

## Common pitfalls

> [!WARNING]
> **Upgrading `istiod` without upgrading `base`.** It often seems to work, then fails on a field the older CRDs do not accept, possibly much later.
>
> **Stopping at the control plane.** `helm upgrade` finishing is not the upgrade finishing. Until you restart the workloads, the data plane runs the old version.
>
> **Forgetting the gateways.** They are separate releases *and* separate workloads: they need their own `helm upgrade`, and a check with `istioctl version` that their pods run the new proxy.
>
> **Skipping a minor version.** The supported skew is one minor version. Go 1.28 to 1.29 to 1.30, restarting the data plane between steps, not 1.28 straight to 1.30.
>
> **Leaving out `--wait` in a pipeline.** Helm returns as soon as the API server accepts the manifests, and the next command runs against a control plane that is not ready yet.

## Your mission: Upgrade And Reconfigure Istio With Helm Lab

You can now recover a release's values, upgrade the three releases in order, and finish the job by restarting the data plane. The lab asks you to upgrade a Helm-installed Istio from 1.29.8 to 1.30.5 without losing a single setting, change one mesh option on the way, and leave no version skew behind.

The lab runs on its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-013-playground-030-01
```

Then start the lab. The task is on the next page; solve it on your own first:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/module-01/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-013-lab-030-01
astrona start ats-013-playground-030-01
```
