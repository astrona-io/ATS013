# Part 1 — Replacing The Control Plane

> Prerequisite: [the module landing page](./course.md). Next: [Part 2 — Skew, Completion And The Cost Of Reverting](./course-02-skew-completion-and-reverting.md).

"In place" is a precise statement about object identity, not a vague one about style. This part pins down exactly which objects are replaced and which keep their names, runs the pre-flight check that makes the upgrade survivable, and performs it — including the one flag mistake that quietly discards a cluster's customisation.

## What "in place" means at the object level

Compare the two strategies by what they do to the cluster's objects:

```text
  IN-PLACE                                CANARY
  ────────                                ──────
  Deployment  istiod         (updated)    Deployment  istiod          (untouched)
  Service     istiod         (untouched)  Deployment  istiod-1-30-5   (new)
  Webhook     istio-sidecar-injector      Service     istiod-1-30-5   (new)
                             (updated)    Webhook     istio-sidecar-injector-1-30-5
                                                                      (new)
  → one control plane, new image          → two control planes, both running
```

An in-place upgrade **reuses the same revision**, so every object keeps its name and Istio's reconciliation updates it rather than creating a sibling. Kubernetes then rolls the `istiod` Deployment the way it rolls any Deployment: new pod up, old pod down, one object throughout.

That single fact explains both the appeal and the risk. There is nothing to relabel, because no name changed. There is also nothing to fall back to, because the old control plane's Deployment no longer exists in its old form.

The sequence is fixed and has **three** steps, not two:

1. **Pre-check** with the target version, to find conditions that would make the upgrade fail.
2. **Install** the new version over the existing revision.
3. **Restart** every injected workload so the data plane catches up.

Step 3 is the one people drop, and the mesh keeps working well enough afterwards that the omission can survive for months. Part 2 is largely about it.

> [!TIP]
> **Try it — establish the baseline you will compare against**
>
> ```sh
> istioctl version
> kubectl -n istio-system get deploy istiod -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
> kubectl -n istio-system get deploy istiod -o jsonpath='{.metadata.uid}{"\n"}'
> istioctl proxy-status
> ```
>
> Expect something like:
>
> ```text
> client version: 1.29.8
> control plane version: 1.29.8
> data plane version: 1.29.8 (3 proxies)
>
> docker.io/istio/pilot:1.29.8
> 4b1e9c2a-3d77-4f21-9c8e-2a1f6d4b8e03
>
> NAME                                     CLUSTER      CDS      LDS      EDS      RDS        ISTIOD
> istio-ingressgateway-...istio-system     Kubernetes   SYNCED   SYNCED   SYNCED   NOT SENT   istiod-...
> notification-service-v1-...inplace-demo  Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED     istiod-...
> notification-service-v1-...inplace-demo  Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED     istiod-...
> ```
>
> Write down the Deployment's `uid` as well as the version. After the upgrade the image will have changed and the `uid` will not — that is "in place" made checkable, rather than taken on trust.

## What `x precheck` inspects, and why the binary matters

`istioctl x precheck` is a read-only audit run against the cluster's API server. It is not a syntax check on your configuration; it asks whether *this cluster* can accept *this version* of Istio. Concretely it examines:

- **The Kubernetes version**, against the target release's supported range.
- **Existing Istio CRDs**, for schemas the target version cannot work with.
- **Existing webhook configurations**, because a stale mutating webhook pointing at a dead service will intercept and fail the install's own pod creations.
- **Existing Istio configuration objects**, for fields the target version has deprecated or removed.
- **Cluster permissions** the install needs — creating CRDs, cluster roles, webhook configurations.

Run it with the **new** binary. The check is about compatibility with the version you are moving *to*, and only that binary carries the target version's requirements and deprecation list. Running `istioctl x precheck` with the currently-installed binary answers a question you already know the answer to.

> [!TIP]
> **Try it — ask the target version whether the cluster is ready**
>
> ```sh
> istioctl-1.30.5 x precheck
> ```
>
> Expect something like:
>
> ```text
> ✔ No issues found when checking the cluster. Istio is safe to install or upgrade!
>   To get started, check out https://istio.io/v1.30/docs/setup/getting-started/
> ```
>
> On a clean playground this passes trivially. On a cluster with real history it rarely does, and the warnings are the valuable output: they name configuration that will stop working after the upgrade, while the old version is still running and you still have options. Read every line — `precheck` warnings are advisory, so a non-zero finding does not block the install.

A related command is worth pairing with it. `istioctl analyze` asks a different question — not "can this cluster take the new version?" but "is the Istio configuration currently in it coherent?". Run `precheck` before the upgrade and `analyze` after, and you have covered both directions.

## Performing the upgrade

The upgrade is `istioctl install` run with the newer binary. There is also an `istioctl upgrade` command, and on 1.30 its help text says plainly that it **is an alias for the install command** — same flags, same behaviour. Use whichever reads better in your runbook; they do the same thing, and neither one restarts your workloads.

Because `install` reconciles the cluster to the document you give it — [Part 4 of the section 010 istioctl module](../../section-010/module-01/course-04-reconciliation-and-removal.md) covers the mechanism — **you must pass the same configuration you installed with**.

This is the in-place equivalent of the Helm module's missing-`-f` incident, and it fails the same way: silently, with a success message. A bare `istioctl install -y` during an upgrade does not mean "keep everything and change the version". It means "make the cluster match the default profile", which reverts every customisation the cluster had.

| How you installed | How you upgrade |
| --- | --- |
| `istioctl install -f istio.yaml` | `istioctl-<new> install -f istio.yaml -y` |
| `istioctl install --set profile=demo` | `istioctl-<new> install --set profile=demo -y` |
| Nobody remembers | Recover it first — see below |

If nobody knows how the cluster was installed, recover before upgrading rather than after. Istio has no "what is installed" command, so the reconstruction comes from the cluster: the `istio` ConfigMap holds the effective `meshConfig`, `kubectl -n istio-system get deploy` shows which components exist, and each Deployment's pod spec shows its resource settings. Write that into a file, then diff `istioctl manifest generate -f <your file>` against `istioctl manifest generate --set profile=default` to see the deviations, and upgrade with the file.

This playground was installed with `--set profile=default`, so that is what the upgrade repeats.

> [!TIP]
> **Try it — replace the control plane, and prove it was in place**
>
> ```sh
> istioctl-1.30.5 install --set profile=default -y
> kubectl -n istio-system get deploy istiod -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
> kubectl -n istio-system get deploy istiod -o jsonpath='{.metadata.uid}{"\n"}'
> kubectl -n istio-system get pods -l app=istiod
> ```
>
> Expect something like:
>
> ```text
> ✔ Istio core installed
> ✔ Istiod installed
> ✔ Ingress gateways installed
> ✔ Installation complete
>
> docker.io/istio/pilot:1.30.5
> 4b1e9c2a-3d77-4f21-9c8e-2a1f6d4b8e03
> NAME                      READY   STATUS    RESTARTS   AGE
> istiod-5f4c9d8b7c-w8t4n   1/1     Running   0          38s
> ```
>
> New image, **same `uid`** as the one you noted earlier, and a freshly created pod. The Deployment object was never deleted and recreated — Istio updated it and Kubernetes rolled its pods. That is exactly what distinguishes this from the canary module, where a second Deployment with a different name appeared.

## The brief control plane gap

Rolling the `istiod` Deployment means there is a short window with no ready control plane pod, or with one that is still starting. What happens during it is worth knowing so it does not alarm you:

- **Existing proxies keep serving traffic.** They hold their last-received configuration and do not need `istiod` to forward a request.
- **Configuration changes do not propagate.** An `apply` during the gap is stored but not pushed until the new control plane is up.
- **New pods in injected namespaces fail to start.** The injection webhook's `failurePolicy` is `Fail`, so admission rejects them rather than creating un-injected pods. This is the correct behaviour and it does mean a deployment attempted during the gap will error.
- **Certificate signing pauses.** Irrelevant over seconds; relevant if the control plane stays down.

For a single-replica `istiod` on a small cluster the gap is a few seconds. Running `istiod` with two or more replicas removes it entirely, which is the usual production setting and worth having in place before you need it.

> *In place means the same objects with a new image — same names, same uid, nothing to relabel and nothing to fall back to.*

## Reference

- [In-place upgrades](https://istio.io/v1.30/docs/setup/upgrade/in-place/) — Istio's own procedure.
- [istioctl x precheck](https://istio.io/v1.30/docs/reference/commands/istioctl/#istioctl-experimental-precheck) — what the check covers.
- [Upgrade overview](https://istio.io/v1.30/docs/setup/upgrade/) — how Istio frames the choice between in-place and canary.
- `istioctl install --help` — confirm that `upgrade` has been folded into `install` on the version you have.
