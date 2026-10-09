# Upgrading In Order And Finishing The Job

With a complete values file in hand, the upgrade itself is three commands in a fixed order. Then comes a fourth step that most people skip, because the mesh keeps working without it. This part covers the order and the step that really finishes the job.

The values file used here is `istiod-values.yaml`, rebuilt from revision 1 of the `istiod` release with `helm get values istiod -n istio-system --revision 1 | tail -n +2 > istiod-values.yaml`. If it is not in your working folder, run that command first.

## The order, and why it holds

The order is `base`, then `istiod`, then each gateway. It is the same order as the install, for a related but different reason.

### Why `base` comes first

At install time the rule was absolute. `istiod`'s objects are of kinds that `base` defines (the Custom Resource Definitions, or CRDs: the new forms the cluster's registry office learns to accept). So `istiod` could not go first.

At upgrade time the CRDs already exist, so a wrong order often *seems* to work. The rule is now about the schema. A newer `istiod` may set fields on Istio objects that only the newer CRDs accept. Upgrade `istiod` first, and it may write or check configuration that the old CRDs reject. Sometimes that fails at once. Sometimes it fails only when someone next applies a certain object.

That "sometimes later" makes the wrong order worse than a clean failure. Keep the order.

### Which release gets which values file

Only `istiod` takes `-f istiod-values.yaml`. `base` and the gateway were installed without a values file, so chart defaults are the right desired state for them. That is a fact about this install, not a general rule. Whatever file a release was installed with is the file you upgrade it with.

## Make the change in the file

The upgrade should also switch the mesh-wide outbound traffic policy from `ALLOW_ANY` to `REGISTRY_ONLY`. Make that change by editing the file, not by adding a `--set`. That keeps the file complete.

<!-- astrona:playground:renew -->

Edit the file in place:

```sh
sed -i.bak 's/mode: ALLOW_ANY/mode: REGISTRY_ONLY/' istiod-values.yaml && rm -f istiod-values.yaml.bak
```

`-i` takes no argument on GNU sed but needs one on the BSD sed that ships with macOS. `-i.bak` works on both: it edits in place and leaves a backup, which the `rm` then removes.

## Upgrade all three releases

Now run the three upgrades in order, and check that the settings survived.

### See it in your playground

Upgrade `base`, `istiod` and the gateway, then read the releases and the mesh settings:

```sh
helm upgrade istio-base istio/base -n istio-system --version 1.30.5 --wait
helm upgrade istiod istio/istiod -n istio-system --version 1.30.5 -f istiod-values.yaml --wait
helm upgrade istio-ingressgateway istio/gateway -n istio-ingress --version 1.30.5 --wait
helm ls -A
kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep -A2 -E 'accessLogFile|outboundTrafficPolicy'
```

Expect something like:

```text
NAME                    NAMESPACE       REVISION  STATUS    CHART           APP VERSION
istio-base              istio-system    2         deployed  base-1.30.5     1.30.5
istio-ingressgateway    istio-ingress   2         deployed  gateway-1.30.5  1.30.5
istiod                  istio-system    5         deployed  istiod-1.30.5   1.30.5

accessLogFile: /dev/stdout
outboundTrafficPolicy:
  mode: REGISTRY_ONLY
```

The new chart version is everywhere, the settings are intact, and the one change you wanted is there. `istiod` shows a higher revision than the others because each earlier experiment with it in this playground added a revision. The history records what happened, not what you meant.

## The data plane has not moved

Upgrading `istiod` replaces mission control's pod. It does not touch your application pods.

### Why the sidecars stay old

Each application pod still runs the sidecar image it was **injected with**. The injection webhook (the dock inspector who puts a communications officer on each new ship) wrote that image into the pod when the pod was created. A control plane upgrade never rewrites a stored pod spec.

That state is **version skew**: a new mission control giving orders to communications officers on old software. Istio supports a skew of one minor version. That is exactly what makes a rolling upgrade possible: in a large mesh there is no single moment when every proxy changes together.

Two commands make it visible:

- `istioctl version` splits `data plane version` into groups when proxies disagree.
- `istioctl proxy-status` lists every proxy, so you can see *which* ones are behind.

### See the gap between control plane and proxies

Read the versions, then the image of the application's sidecar:

```sh
istioctl version
kubectl -n default get pod -l app=notification-service \
  -o jsonpath='{.items[0].spec.containers[?(@.name=="istio-proxy")].image}{"\n"}'
```

Expect something like:

```text
client version: 1.29.8
control plane version: 1.30.5
data plane version: 1.29.8 (2 proxies)

docker.io/istio/proxyv2:1.29.8
```

Three answers on one screen. Your `istioctl` binary is old, the control plane is new, and the proxies are still old. Only the third is a real problem, and only a restart fixes it. The first is cosmetic: `istioctl` is a client, and an old client talking to a new control plane just gives slightly less useful diagnostics.

## Finishing the upgrade

A proxy gets a new image the only way any container does: Kubernetes replaces the pod. `kubectl rollout restart deployment` asks the Deployment controller to do that, a few pods at a time. In space terms, you relaunch the ships so each one gets a fresh communications officer.

Gateways count too. An ingress gateway is an Envoy workload, and the control plane upgrade does not restart it. It is also the one whose old version is most visible from outside the cluster.

### See the data plane come across

Restart the application and the gateway, wait, and read the versions again:

```sh
kubectl -n default rollout restart deployment
kubectl -n istio-ingress rollout restart deployment istio-ingressgateway
kubectl -n default rollout status deployment notification-service --timeout=180s
istioctl version
```

Expect something like:

```text
client version: 1.29.8
control plane version: 1.30.5
data plane version: 1.30.5 (2 proxies)
```

A single `data plane version` that matches the control plane means the upgrade is complete. If two versions are still listed, something was not restarted. `istioctl proxy-status` names the workloads, and the answer is usually a Deployment in a namespace nobody remembered was in the mesh.

### Find the planets you forgot

This command lists every namespace with the injection label:

```sh
kubectl get ns -l istio-injection=enabled
```

Every namespace in that list needs a restart. A workload that joined the mesh through a pod-level label instead of a namespace label does not show up here. `istioctl proxy-status` stays the full list.

The upgrade is not finished when Helm says `deployed`. It is finished when `istioctl version` reports one data plane version.

## Common pitfalls

> [!WARNING]
> **Upgrading `istiod` without upgrading `base`.** It often seems to work, then fails on a field the older CRDs do not accept, possibly much later.
>
> **Stopping at the control plane.** `helm upgrade` finishing is not the upgrade finishing. Until you restart the workloads, the data plane runs the old version.
>
> **Forgetting the gateways.** They are separate releases *and* separate workloads: they need both the `helm upgrade` and the `rollout restart`.
>
> **Skipping a minor version.** The supported skew is one minor version. Go 1.28 to 1.29 to 1.30, restarting the data plane between steps, not 1.28 straight to 1.30.
>
> **Leaving out `--wait` in a pipeline.** Helm returns as soon as the API server accepts the manifests, and the next command runs against a control plane that is not ready yet.
