# Part 4 — Reconciliation And Clean Removal

> Prerequisite: [Part 3 — Injection And The Version Triad](./course-03-injection-and-version-alignment.md). Next: [the module landing page](./course.md), then [Module 2 — Install Istio With Helm](../module-02/course.md).

Part 1 said `istioctl install` renders a complete desired state and applies it. This part takes that sentence to its conclusion: what happens when you run it a *second* time with different input, how Istio decides which of your existing objects to delete, and what `uninstall` does and does not remove. Everything here is a consequence of "declarative", and every item is a real incident someone has had.

## The second install is not an addition

Concretely: install `demo`, then install `minimal` on top of it. `minimal` renders a document that contains `istiod` and no gateways. Reconciling the cluster to that document means the gateway Deployments are **deleted**.

The general rule: **`istioctl install` makes the cluster match the document you passed, which means components present only in the previous document are removed.** Nothing warns you beyond the install summary, because from Istio's point of view you asked for `minimal` and `minimal` is what you got.

This extends past whole components to individual fields. A `meshConfig.accessLogFile` you set last time and omit this time does not keep its value — it reverts to whatever the profile says, which usually means the default. Section 020's customisation module works through the field-level case; the component-level case is easier to see, so start there.

> [!TIP]
> **Try it — watch reconciliation remove something**
>
> This changes the cluster: it deletes both gateway Deployments. On the playground that is the point; on a real cluster it would drop ingress traffic.
>
> ```sh
> kubectl -n istio-system get deploy
> istioctl install --set profile=minimal -y
> kubectl -n istio-system get deploy
> ```
>
> Expect something like:
>
> ```text
> NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
> istio-egressgateway    1/1     1            1           8m
> istio-ingressgateway   1/1     1            1           8m
> istiod                 1/1     1            1           8m
>
> ✔ Istio core installed
> ✔ Istiod installed
> ✔ Installation complete
>
> NAME     READY   UP-TO-DATE   AVAILABLE   AGE
> istiod   1/1     1            1           8m
> ```
>
> Two Deployments gone, and the only signal was the *absence* of "Ingress gateways installed" in the summary. Note that `istiod`'s `AGE` did not reset — reconciliation updated the object it already owned rather than recreating it.

## How Istio knows what to prune

Deleting things the user did not mention is only safe if Istio can tell its own objects from yours. It does that with ownership labels written onto every object the install creates.

The load-bearing one is `install.operator.istio.io/owning-resource`, alongside `operator.istio.io/component` naming which component an object belongs to and `istio.io/rev` naming the revision that owns it. On each install, Istio renders the new manifest set, lists the existing objects carrying its ownership labels for that revision, and deletes the ones that are no longer in the rendered set.

Three consequences worth knowing:

- **Objects you created by hand are not pruned.** A `VirtualService` you applied has none of these labels, so reconciliation ignores it entirely. Install-time reconciliation only touches install-time objects.
- **Pruning is scoped to a revision.** An install of revision `1-30-5` does not prune objects owned by the default revision. That scoping is exactly what makes canary upgrades possible — two control planes coexist because neither one's reconciliation can see the other's objects.
- **Hand-edits to installed objects are silently reverted.** If you `kubectl edit` the `istiod` Deployment, nothing undoes it immediately (Part 1: there is no in-cluster operator), but the next `istioctl install` renders the object from the document and overwrites your change. The edit survives exactly until someone runs the install again, which is the worst possible duration.

> [!TIP]
> **Try it — read the ownership labels**
>
> ```sh
> kubectl -n istio-system get deploy istiod -o jsonpath='{.metadata.labels}{"\n"}' | tr ',' '\n' | grep -E 'operator|rev'
> ```
>
> Expect something like:
>
> ```text
> "install.operator.istio.io/owning-resource":"unknown"
> "operator.istio.io/component":"Pilot"
> "istio.io/rev":"default"
> ```
>
> `component: Pilot` is the control plane under its historical name, and `istio.io/rev: default` is what scopes the pruning. Exact label values vary by version; their presence is what matters — these are the marks that make an object reconcilable.

## Removing one revision, or all of it

`istioctl uninstall` has two modes and the difference is not cosmetic.

- **`istioctl uninstall --revision <name>`** removes one named control plane and the objects labelled for it. Everything else survives, including the CRDs and any other revision. This is what you use to retire an old revision after a canary upgrade, and using it is the normal case.
- **`istioctl uninstall --purge`** removes **every** revision and all cluster-scoped Istio resources, CRDs included. This is what you use to get back to a genuinely clean cluster, and it is a mistake in the middle of an upgrade because it takes the new control plane with the old one.

Neither one removes the `istio-system` namespace itself, and neither un-labels namespaces you opted into injection. So a full cleanup is three commands, not one.

> [!WARNING]
> **`--purge` during a canary upgrade removes the canary too**
>
> The flag means "every revision", and a canary is a revision. If you are running two control planes and want to retire one, always name it: `istioctl uninstall --revision default -y`. Section 030's canary module goes through the ordering in detail.

## What survives an uninstall

Removing Istio is less complete than it looks, and each leftover has a reason:

- **CRDs stay unless `--purge` is used.** They are cluster-scoped and shared between revisions, so removing them on a per-revision uninstall would break the revisions still running.
- **Namespace labels stay.** `istio-injection=enabled` is on *your* namespace object, which Istio does not own. It becomes inert — the webhook it points at is gone — and reactivates the moment someone installs Istio again.
- **Existing pods keep their sidecars.** Injection happened at creation (Part 3) and the container is part of the stored pod spec. Those proxies keep running with no control plane to talk to: no configuration updates, and no certificate renewal when the current one expires.
- **Your Istio configuration objects stay** until the CRDs go, and become unreadable when they do.

The third one is the operationally interesting one. A pod with an orphaned sidecar is not obviously broken — it serves traffic on its last-known configuration — right up until a certificate expires or the workload restarts into a cluster with no injector.

> [!TIP]
> **Try it — prove the cluster is clean, and find what is not**
>
> ```sh
> istioctl uninstall --purge -y
> kubectl delete namespace istio-system --ignore-not-found
> kubectl api-resources --api-group=networking.istio.io
> kubectl get ns default --show-labels
> kubectl get pod tester -o jsonpath='{.spec.containers[*].name}{"\n"}'
> ```
>
> Expect something like:
>
> ```text
> All Istio resources will be pruned from the cluster
> ...
> namespace "istio-system" deleted
> error: unable to retrieve the complete list of server APIs: networking.istio.io/v1: the server could not find the requested resource
>
> NAME      STATUS   AGE   LABELS
> default   Active   41m   istio-injection=enabled,kubernetes.io/metadata.name=default
>
> nginx istio-proxy
> ```
>
> The CRDs are genuinely gone — the same error you saw before the very first install. But the namespace is still labelled, and `tester` still has a sidecar with nothing to talk to. Finish the job with `kubectl label namespace default istio-injection-` and `kubectl delete pod tester`.

> [!WARNING]
> **Common pitfalls**
>
> - **"The second install added `minimal` on top of `demo`."** It did not. Reconciliation removes components the new document does not contain. Keep one `IstioOperator` file as the source of truth and pass it every time.
> - **`--set` flags as the installation record.** They exist in your shell history and nowhere else, and the cluster shows the result rather than the inputs. Commit a file.
> - **Hand-editing an installed object.** It works until the next install, then silently reverts. Change the document instead.
> - **`istioctl uninstall` without `--purge`, expecting a clean cluster.** The CRDs stay. The next install starts on top of stale definitions, which is exactly what `x precheck` warns about.
> - **`--purge` mid-upgrade.** It removes every revision, canary included.
> - **Assuming uninstall removes sidecars.** It does not. Existing pods keep the proxy container until they are recreated.
> - **`istioctl` and Helm both owning one cluster.** Two reconcilers, two sets of ownership labels, changes that revert unpredictably. Pick one method per cluster.

## Making the install reproducible

Everything above argues for one habit, so it is worth stating as a rule rather than leaving implied: **the installation is a file, committed, passed with `-f` on every run.** That gives you a document to diff before applying, a manifest to review (`istioctl manifest generate -f`), and an unambiguous answer to what the cluster is supposed to look like.

`--set` is fine for a throwaway experiment. Section 020's customisation module builds the file properly, and section 030's upgrade modules depend on it existing.

> *Reconciliation deletes what your new document omits, and uninstall leaves more behind than it removes — both follow from "declarative", and both surprise people exactly once.*

## Reference

- [Uninstall Istio](https://istio.io/v1.30/docs/setup/install/istioctl/#uninstall-istio) — the `--revision` and `--purge` semantics.
- [Canary upgrades](https://istio.io/v1.30/docs/setup/upgrade/canary/) — why revision-scoped pruning is what makes two control planes possible.
- [IstioOperator API](https://istio.io/v1.30/docs/reference/config/istio.operator.v1alpha1/) — the document reconciliation targets.
- `istioctl uninstall --help` — confirm the flag behaviour on the version you have before running it on anything real.
