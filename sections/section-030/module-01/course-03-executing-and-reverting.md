# Part 3 — Executing And Reverting An Upgrade

> Prerequisite: [Part 2 — How `helm upgrade` Computes Values](./course-02-how-upgrade-computes-values.md). Next: [the module landing page](./course.md), then [Module 2 — Canary Upgrade With Revisions And Revision Tags](../module-02/course.md).

With a values file in hand, the upgrade itself is three commands in a fixed order — and then a fourth step that most people skip, because the mesh keeps working without it. This part covers the order, the step that actually finishes the job, and what `helm rollback` restores when it goes wrong.

## The order, and why it holds

`base`, then `istiod`, then each gateway. The same order as the install, for a related but not identical reason.

At install time the constraint was absolute: `istiod`'s objects are of kinds that `base` defines, so they cannot exist first. At upgrade time the CRDs already exist, so a wrong order often *appears* to work. The constraint is now about schema: a newer `istiod` may set fields on Istio resources that only the newer CRDs accept. Upgrade `istiod` first and it can produce or validate configuration the old CRDs reject — sometimes immediately, sometimes only when a particular resource is next applied.

That "sometimes later" is what makes the wrong order worse than a clean failure. Keep the order.

```sh
helm upgrade istio-base istio/base -n istio-system --version 1.30.5 --wait
helm upgrade istiod istio/istiod -n istio-system --version 1.30.5 -f istiod-values.yaml --wait
helm upgrade istio-ingressgateway istio/gateway -n istio-ingress --version 1.30.5 --wait
```

Note the `-f` on the middle line and its absence on the other two. `base` and `gateway` were installed without a values file, so chart defaults are the correct desired state for them — but that is a fact about this particular install, not a general rule. Whatever file a release was installed with is the file it must be upgraded with.

Make the configuration change you actually wanted by editing the file, not by adding a `--set`:

```sh
sed -i.bak 's/mode: ALLOW_ANY/mode: REGISTRY_ONLY/' istiod-values.yaml && rm -f istiod-values.yaml.bak
```

> `-i` takes no argument on GNU sed but requires one on the BSD sed that ships
> with macOS. `-i.bak` works on both: it edits in place and leaves a backup,
> which the `rm` then removes.

That keeps the file complete, which is the entire point of Part 2.

> [!TIP]
> **Try it — upgrade all three, and confirm the values survived**
>
> ```sh
> helm upgrade istio-base istio/base -n istio-system --version 1.30.5 --wait
> helm upgrade istiod istio/istiod -n istio-system --version 1.30.5 -f istiod-values.yaml --wait
> helm upgrade istio-ingressgateway istio/gateway -n istio-ingress --version 1.30.5 --wait
> helm ls -A
> kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep -A2 -E 'accessLogFile|outboundTrafficPolicy'
> ```
>
> Expect something like:
>
> ```text
> NAME                    NAMESPACE       REVISION  STATUS    CHART           APP VERSION
> istio-base              istio-system    2         deployed  base-1.30.5     1.30.5
> istio-ingressgateway    istio-ingress   2         deployed  gateway-1.30.5  1.30.5
> istiod                  istio-system    5         deployed  istiod-1.30.5   1.30.5
>
> accessLogFile: /dev/stdout
> outboundTrafficPolicy:
>   mode: REGISTRY_ONLY
> ```
>
> New chart version everywhere, settings intact, and the one change you intended. `istiod` is on a much higher revision than the others because it absorbed Part 2's deliberate mistakes — the history records what happened, not what you meant.

## The data plane has not moved

Upgrading `istiod` replaces the control plane pod. It does not touch your application pods, and each of those is still running the sidecar image it was **injected with**, at pod creation, by the version of the webhook that was live at the time. Nothing about a control plane upgrade rewrites a stored pod spec.

That state is **version skew**: a new control plane serving old proxies. Istio supports it across one minor version, which is exactly what makes a rolling upgrade possible — there is no instant at which every proxy in a large mesh changes together.

Two commands make it visible:

- `istioctl version` — splits `data plane version` into groups when proxies disagree.
- `istioctl proxy-status` — lists every proxy, so you can see *which* ones are behind.

> [!TIP]
> **Try it — see the gap between control plane and proxies**
>
> ```sh
> istioctl version
> kubectl -n default get pod -l app=notification-service \
>   -o jsonpath='{.items[0].spec.containers[?(@.name=="istio-proxy")].image}{"\n"}'
> ```
>
> Expect something like:
>
> ```text
> client version: 1.29.8
> control plane version: 1.30.5
> data plane version: 1.29.8 (2 proxies)
>
> docker.io/istio/proxyv2:1.29.8
> ```
>
> Three different answers on one screen: your `istioctl` binary is old, the control plane is new, and the proxies are still old. Only the third is a real problem, and only a restart fixes it. The first is cosmetic — `istioctl` is a client, and an old client talking to a new control plane produces slightly less useful diagnostics, nothing more.

## Finishing the upgrade

A proxy gets a new image the only way any container does: the pod is replaced. `kubectl rollout restart deployment` triggers that through the Deployment controller, gradually.

Gateways count. An ingress gateway is an Envoy workload that the control plane upgrade does not restart, and it is the one whose staleness is most visible from outside the cluster.

```sh
kubectl -n default rollout restart deployment
kubectl -n istio-ingress rollout restart deployment istio-ingressgateway
kubectl -n default rollout status deployment notification-service --timeout=180s
```

> [!TIP]
> **Try it — bring the data plane across and confirm**
>
> ```sh
> kubectl -n default rollout restart deployment
> kubectl -n istio-ingress rollout restart deployment istio-ingressgateway
> kubectl -n default rollout status deployment notification-service --timeout=180s
> istioctl version
> ```
>
> Expect something like:
>
> ```text
> client version: 1.29.8
> control plane version: 1.30.5
> data plane version: 1.30.5 (2 proxies)
> ```
>
> A single `data plane version` matching the control plane is the upgrade being complete. If two versions are still listed, something was not restarted — `istioctl proxy-status` names the workloads, and the answer is usually a Deployment in a namespace nobody remembered was meshed.

Finding those forgotten namespaces is worth a command of its own:

```sh
kubectl get ns -l istio-injection=enabled
```

Anything in that list needs a restart, and anything meshed by a pod-level label rather than a namespace label will not appear — `istioctl proxy-status` remains the authoritative inventory.

## What `helm rollback` restores

`helm rollback <release> <revision> -n <ns>` re-applies a previous revision's manifests and records the result as a **new** revision. It restores the release's Kubernetes objects and the values that produced them, so the control plane image and the `meshConfig` both revert.

Three things it does not do:

- **It does not restart application pods.** Their sidecars keep running whatever image they were injected with. After rolling the control plane back you may need another rollout restart to bring the data plane with it — the same step as the upgrade, in the other direction.
- **It does not touch other releases.** Rolling `istiod` back to 1.29.8 while `istio-base` stays at 1.30.5 leaves you in a combination nobody tested. A rollback of one release is not a rollback of the install.
- **It does not undo anything outside the release** — CRDs installed by `base`, or resources you created by hand.

> [!TIP]
> **Try it — revert a mesh setting through a rollback**
>
> ```sh
> helm history istiod -n istio-system | tail -4
> helm rollback istiod 1 -n istio-system --wait
> kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep -A2 outboundTrafficPolicy
> kubectl -n istio-system get deploy istiod -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
> helm ls -n istio-system
> ```
>
> Expect something like:
>
> ```text
> Rollback was a success! Happy Helming!
>
> outboundTrafficPolicy:
>   mode: ALLOW_ANY
>
> docker.io/istio/pilot:1.29.8
>
> NAME         NAMESPACE      REVISION  STATUS    CHART          APP VERSION
> istio-base   istio-system   2         deployed  base-1.30.5    1.30.5
> istiod       istio-system   6         deployed  istiod-1.29.8  1.29.8
> ```
>
> The mesh setting is back to its revision-1 value and the control plane image went with it. Note the last two lines carefully: `istio-base` is still on 1.30.5 while `istiod` is back on 1.29.8. That is the "not a rollback of the install" point, visible in two columns.

## A procedure worth writing down

Putting the three parts together, an Istio Helm upgrade is:

1. **Confirm the values file matches reality** — `helm get values` against your committed file. If they differ, find out why before anything else.
2. **Dry-run and read the computed values** — Part 2's check.
3. **Upgrade in order** — `base`, `istiod`, gateways, each pinned with `--version` and passed its own `-f`.
4. **Verify configuration survived** — the `istio` ConfigMap, and whatever settings matter to you.
5. **Restart the data plane** — every meshed namespace, plus gateways.
6. **Verify a single data plane version** — `istioctl version`, then `proxy-status` if it disagrees.

Steps 4 and 6 are the ones that catch the two failure modes this module is about, and they are the two people leave out.

> [!WARNING]
## Common pitfalls

> [!WARNING]
> **Upgrading `istiod` without upgrading `base`.** It often appears to work and then fails on a field the older CRDs do not accept, possibly much later.
>
> **Stopping at the control plane.** `helm upgrade` finishing is not the upgrade finishing. Until the workloads are restarted, the data plane is on the old version.
>
> **Forgetting the gateways.** They are separate releases *and* separate workloads: they need both the `helm upgrade` and the `rollout restart`.
>
> **Skipping a minor version.** The supported skew window is one minor version. Go 1.28 → 1.29 → 1.30, restarting the data plane between steps, not 1.28 → 1.30.
>
> **Treating `helm rollback` as a full undo.** It restores one release's objects, not the pods created from them and not sibling releases.
>
> **Omitting `--wait` in a pipeline.** Helm returns as soon as the API server accepts the manifests, and the next command runs against a control plane that is not ready.

## Operational considerations

**Count the restart bill before you start.** Completing the upgrade means replacing every meshed pod. Check `PodDisruptionBudget`s, decide whether it is a maintenance window or a background task, and restart least-critical namespaces first so a problem shows up while most of the mesh is still on the old proxy.

**The release history is a real dependency.** Rollback and value recovery both live in those Secrets. Back up the namespace, and commit the values file so the cluster is not the only copy.

**Watch certificate issuance, not just pod status.** `istiod` is also the certificate authority. A workload that cannot get a fresh certificate keeps working until its current one expires, then fails in a way that looks unrelated to the upgrade. A quiet mesh immediately afterwards is not proof of a healthy one.

**Helm rollback is not Istio rollback.** Reverting the control plane leaves the data plane wherever it was. The canary strategy in the next module exists precisely because it turns the revert into a label change rather than a second full rollout.

> *The upgrade is not finished when Helm says `deployed` — it is finished when `istioctl version` reports one data plane version, and rollback only takes back what one release owns.*

## Reference

- [Upgrade Istio with Helm](https://istio.io/v1.30/docs/setup/upgrade/helm/) — Istio's own upgrade order and caveats.
- [helm rollback](https://helm.sh/docs/helm/helm_rollback/) — semantics and the new-revision behaviour.
- [Supported releases and skew](https://istio.io/v1.30/docs/releases/supported-releases/) — the one-minor-version rule.
- [Diagnostic tools](https://istio.io/v1.30/docs/ops/diagnostic-tools/proxy-cmd/) — `proxy-status` output during and after an upgrade.
