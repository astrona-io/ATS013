# Part 1 — Revisions: A Named Control Plane

> Prerequisite: [the module landing page](./course.md). Next: [Part 2 — Selecting, Moving And Retiring A Revision](./course-02-selecting-moving-retiring.md).

A canary upgrade works because two Istio control planes can run in one cluster without noticing each other. That is not a special mode — it falls out of how revisions name and scope every object an install creates. This part settles what a revision is at the object level, so that Part 2's label work is obviously correct rather than something to memorise.

## What `--set revision=` changes

Concretely, compare two installs:

```text
istioctl install --set profile=minimal -y
  ├─ Deployment   istiod
  ├─ Service      istiod
  └─ MutatingWebhookConfiguration  istio-sidecar-injector

istioctl install --set profile=minimal --set revision=1-30-5 -y
  ├─ Deployment   istiod-1-30-5
  ├─ Service      istiod-1-30-5
  └─ MutatingWebhookConfiguration  istio-sidecar-injector-1-30-5
```

The general rule: **a revision is a named, independent instance of the control plane, and every namespaced object it owns carries the name as a suffix.** Without a revision name, an install is "the default revision" — which is why the existing `istiod` has no suffix and its webhook does not either.

Three properties follow, and together they are the whole canary mechanism:

**Names do not collide.** Two Deployments, two Services, two webhook configurations. Kubernetes has no reason to object.

**Reconciliation is revision-scoped.** [Part 4 of the section 010 istioctl module](../../section-010/module-01/course-04-reconciliation-and-removal.md) covered the ownership labels Istio prunes by. Those labels include `istio.io/rev`, so an install of `1-30-5` lists and prunes only objects owned by `1-30-5`. It cannot see the default revision's objects, so it cannot delete them.

**Webhook selectors do not overlap.** The default webhook matches namespaces labelled `istio-injection=enabled`; the revisioned one matches `istio.io/rev=1-30-5`. A namespace satisfies one or the other, and Part 2 covers what happens when someone makes it satisfy both.

Some cluster-scoped objects are genuinely shared — the CRDs from the `base` component are installed once and used by every revision. That is fine, because CRDs are definitions, and it is also why `istioctl uninstall --purge` is so destructive during a canary: removing the shared definitions takes both control planes down.

## Revision names are DNS labels

Revision names become part of Kubernetes object names, so they must be valid DNS labels: lowercase alphanumerics and dashes, starting and ending with an alphanumeric, no dots.

That is why the convention is `1-30-5` rather than `1.30.5`. Any name works — `canary`, `next`, `blue` — but encoding the version makes `kubectl get pods` self-documenting, and makes it obvious months later which revision is the old one.

A dotted name does not produce a helpful error at the point you make the mistake; it produces an invalid object name deeper in the install. Getting into the habit of writing dashes costs nothing.

## Install `minimal` for a canary control plane

The canary install below uses the `minimal` profile, which installs `istiod` and nothing else. That is deliberate and worth the sentence: a canary needs a second **control plane**, not a second copy of the gateways.

Gateways are not selected by a namespace injection label — they are standalone Envoy Deployments created by the profile. Installing a full profile as a canary means two gateway Deployments contending for the same names and the same Service, which is a different and much messier problem than the one you are trying to solve. Gateways are migrated separately, as their own rollout, once the control plane is proven.

> [!TIP]
> **Try it — a second control plane, side by side**
>
> ```sh
> istioctl-1.30.5 install --set profile=minimal --set revision=1-30-5 -y
> kubectl -n istio-system get pods -l app=istiod
> kubectl -n istio-system get svc | grep istiod
> kubectl get mutatingwebhookconfigurations | grep istio
> ```
>
> Expect something like:
>
> ```text
> NAME                             READY   STATUS    RESTARTS   AGE
> istiod-1-30-5-6b9c8f7d4b-xk2p9   1/1     Running   0          41s
> istiod-77d5f6c8b9-qr4tz          1/1     Running   0          12m
>
> istiod           ClusterIP   10.96.31.4    <none>   15010/TCP,15012/TCP,443/TCP,15014/TCP
> istiod-1-30-5    ClusterIP   10.96.88.17   <none>   15010/TCP,15012/TCP,443/TCP,15014/TCP
>
> istio-revision-tag-default            ...   12m
> istio-sidecar-injector                ...   12m
> istio-sidecar-injector-1-30-5         ...   41s
> ```
>
> Two `istiod` pods, two Services, and a suffixed webhook configuration. The two Services matter more than they look: a sidecar's `discoveryAddress` points at one of them, which is how a proxy ends up permanently attached to one control plane rather than the other.

## Installing a revision moves nothing

This is the part people find surprising, and it follows directly from injection. The new control plane has a webhook, but no namespace is labelled for it — and even a relabelled namespace only affects pods created afterwards. Your running workload was injected against the old control plane, points at the old control plane's Service, and stays there.

`istioctl proxy-status` is where this becomes checkable. Its last column, `ISTIOD`, names the control plane *pod* each proxy is connected to, which is the only authoritative answer to "which control plane is serving this workload?"

> [!TIP]
> **Try it — nothing has changed for the workload**
>
> ```sh
> kubectl -n canary-demo get pods
> istioctl proxy-status | grep -E 'NAME|canary-demo'
> ```
>
> Expect something like:
>
> ```text
> NAME                                       READY   STATUS    RESTARTS   AGE
> notification-service-v1-5d9f8b7c6d-p2mzq   2/2     Running   0          13m
>
> NAME                                     CLUSTER      CDS      LDS      EDS      RDS      ISTIOD
> notification-service-v1-...canary-demo   Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED   istiod-77d5f6c8b9-qr4tz
> ```
>
> The pod's `AGE` predates the canary install and `RESTARTS` is still 0. The `ISTIOD` column names the *old*, unsuffixed control plane pod. Installing a revision is completely non-disruptive — which is exactly the property that makes canary upgrades safe to start.

Confirm the other half of the claim while you are here: the new control plane is running and serving nobody.

> [!TIP]
> **Try it — a control plane with no clients**
>
> ```sh
> istioctl-1.30.5 proxy-status --revision 1-30-5
> kubectl -n istio-system logs deploy/istiod-1-30-5 --tail=5 | grep -i 'push\|ads' || echo '(no pushes logged)'
> ```
>
> Expect something like:
>
> ```text
> No proxies connected to the control plane.
>
> (no pushes logged)
> ```
>
> A healthy, running `istiod` with zero connected proxies. It has computed nothing and pushed nothing, because no workload has been told to talk to it. That idle second control plane is the entire cost of a canary upgrade until you start moving namespaces.

## What this costs

Two control planes run for the whole migration. On a small cluster that is noticeable — `istiod`'s default request in the `demo` profile is 500m CPU and 2Gi memory, and the canary is a second copy of that.

It is also the price of a rollback that is a label change rather than a reinstall. The in-place module makes the comparison explicit; the number to hold onto here is that the overlap is temporary and bounded by how quickly you restart workloads.

> *A revision suffixes every namespaced object it owns, which is why two control planes coexist, why reconciliation cannot cross between them, and why installing one changes nothing for running pods.*

## Reference

- [Canary upgrades](https://istio.io/v1.30/docs/setup/upgrade/canary/) — Istio's own procedure and the revision model.
- [Installation configuration profiles](https://istio.io/v1.30/docs/setup/additional-setup/config-profiles/) — what `minimal` installs, and why it suits a canary control plane.
- [Diagnostic tools](https://istio.io/v1.30/docs/ops/diagnostic-tools/proxy-cmd/) — reading the `ISTIOD` column and the `--revision` flag.
- `istioctl install --help` — confirm the `revision` overlay key on the version you have.
