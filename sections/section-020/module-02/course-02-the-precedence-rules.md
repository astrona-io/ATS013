# Part 2 — The Precedence Rules

> Prerequisite: [Part 1 — Injection As Admission Control](./course-01-injection-as-admission-control.md). Next: [Part 3 — What Injection Writes Into The Pod](./course-03-what-injection-writes.md).

Three labels can influence whether a pod is injected and by which control plane. This part states exactly how they combine, and then exercises each rule on the playground's three workloads. The decision table is the single most examinable thing in the module, and the field-location rule underneath it is the single most common mistake.

## The four labels in play

| Label | Goes on | Means |
| --- | --- | --- |
| `istio-injection=enabled` | namespace | Inject, using the **default** control plane |
| `istio.io/rev=<revision-or-tag>` | namespace | Inject, using **that** control plane |
| `sidecar.istio.io/inject="true"` / `"false"` | **pod template** | Override the namespace decision for this workload |
| `istio.io/rev=<revision>` | **pod template** | Pin this workload to a specific control plane |

The two `istio.io/rev` rows are the same label key on two different objects, and they mean the same thing at two different scopes — namespace-wide, or one workload.

## The decision, in order

For a pod being created, evaluate in this order:

```text
 1. Does the pod template carry sidecar.istio.io/inject: "false"?
       yes ──► NOT injected.  Stop.  (beats everything)
       no  ──► continue

 2. Does the pod template carry sidecar.istio.io/inject: "true"?
       yes ──► injected, regardless of namespace labels.  Continue to 4.
       no  ──► continue

 3. Does the namespace carry istio-injection=enabled, or istio.io/rev=<x>?
       neither ──► NOT injected.  Stop.
       either  ──► injected.  Continue to 4.

 4. WHICH control plane?
       pod template istio.io/rev         ──► that revision      (highest)
       else namespace istio-injection    ──► default revision
       else namespace istio.io/rev       ──► that revision
```

Two consequences worth stating as rules in their own right:

**The pod label beats the namespace, in both directions.** `"false"` pulls a workload out of an injected namespace; `"true"` pushes one into an uninjected one. Part 1 showed why — they are two separate webhook entries with complementary selectors.

**`istio-injection` beats `istio.io/rev` on the same namespace.** If both are present, the workload attaches to the *default* control plane and the revision label is ignored — silently, with no warning and no error. This is the trap that makes canary upgrades appear to do nothing, and section 030's canary module hits it directly. Removing the old label is part of moving a namespace to a revision, not an optional tidy-up.

## The field that has to be right

The pod-level labels belong at `spec.template.metadata.labels` — the labels that end up on each *pod*. Not at the Deployment's own `metadata.labels`.

```yaml
kind: Deployment
metadata:
  labels: {}                                    # the webhook never reads this
spec:
  template:
    metadata:
      labels:
        sidecar.istio.io/inject: "false"        # here
```

This follows directly from Part 1: the webhook is registered against `pods`, so its `objectSelector` is evaluated against the pod object. A label on the Deployment is never copied to the pod unless you put it in the template. Both placements apply cleanly, neither errors, and only one has any effect.

Note the quotes. Kubernetes label values are always strings, and an unquoted `false` in YAML is a boolean — the API server rejects the object outright. That one at least fails loudly.

## Opting a workload out

> [!TIP]
> **Try it — keep the log shipper out of the mesh**
>
> ```sh
> kubectl -n inject-demo patch deployment logging-agent -p \
>   '{"spec":{"template":{"metadata":{"labels":{"sidecar.istio.io/inject":"false"}}}}}'
> kubectl -n inject-demo rollout status deployment logging-agent --timeout=120s
> kubectl -n inject-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
> ```
>
> Expect something like:
>
> ```text
> POD                        CONTAINERS
> batch-job-...              batch-job,istio-proxy
> logging-agent-...          logging-agent
> notification-service-...   notification-service,istio-proxy
> ```
>
> `logging-agent` is back to one container. Patching the pod template changes the template hash, which itself triggers a rollout — so no separate `rollout restart` was needed this time. That is worth noticing: a label change that goes *in the template* restarts the workload for you, while a label change on the *namespace* does not.

Now repeat the same patch in the wrong place, because the lesson sticks much better once you have watched it fail. Put the label on the Deployment's own metadata, restart, and check again:

> [!TIP]
> **Try it — the same label, one level too high**
>
> ```sh
> kubectl -n inject-demo patch deployment batch-job -p \
>   '{"metadata":{"labels":{"sidecar.istio.io/inject":"false"}}}'
> kubectl -n inject-demo rollout restart deployment batch-job
> kubectl -n inject-demo rollout status deployment batch-job --timeout=120s
> kubectl -n inject-demo get pod -l app=batch-job -o jsonpath='{.items[0].spec.containers[*].name}{"\n"}'
> kubectl -n inject-demo get deployment batch-job -o jsonpath='{.metadata.labels}{"\n"}'
> ```
>
> Expect something like:
>
> ```text
> batch-job istio-proxy
>
> {"app":"batch-job","sidecar.istio.io/inject":"false"}
> ```
>
> The label is unmistakably present on the Deployment, and the pod is still injected. Nothing rejected it, nothing warned, and a `kubectl get deployment -o yaml` would show exactly what you intended. This silence is what makes the mistake expensive — undo it with `kubectl -n inject-demo label deployment batch-job sidecar.istio.io/inject-` before continuing.

## Forcing a workload in

The same label with `"true"` works the other way: it injects a workload whose namespace has opted out entirely. That is how you mesh one job in a namespace that is otherwise outside the mesh.

> [!TIP]
> **Try it — a meshed workload in an unlabelled namespace**
>
> ```sh
> kubectl -n inject-demo patch deployment batch-job -p \
>   '{"spec":{"template":{"metadata":{"labels":{"sidecar.istio.io/inject":"true"}}}}}'
> kubectl label namespace inject-demo istio-injection-
> kubectl -n inject-demo rollout restart deployment batch-job notification-service
> kubectl -n inject-demo rollout status deployment batch-job --timeout=120s
> kubectl -n inject-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
> ```
>
> Expect something like:
>
> ```text
> namespace/inject-demo unlabeled
>
> POD                        CONTAINERS
> batch-job-...              batch-job,istio-proxy
> logging-agent-...          logging-agent
> notification-service-...   notification-service
> ```
>
> `notification-service` left the mesh when the namespace label went away and it was restarted — step 3 of the decision order, with nothing overriding it. `batch-job` stayed in on its pod-level `"true"` — step 2, which never consults the namespace at all.

Re-label the namespace with `kubectl label namespace inject-demo istio-injection=enabled` before moving on, so Part 3 starts from an injected namespace.

## Choosing a control plane, not just a switch

Step 4 of the decision order only becomes visible when a cluster runs more than one control plane, which is what a canary upgrade creates. `istio-injection=enabled` says "inject, using the default"; `istio.io/rev=<revision-or-tag>` says which one.

The pod-template form of `istio.io/rev` pins a single workload to a revision regardless of its namespace — the tool for canarying one service within a namespace, and subject to the same restart rule as everything else in this module.

This playground runs a single default control plane, so there is no second revision here to pin anything to. Section 030's canary module provides that environment and works through the labels against two live control planes.

> [!WARNING]
> **Common pitfalls**
>
> - **`sidecar.istio.io/inject` on the Deployment's `metadata.labels`.** It must be on `spec.template.metadata.labels`. In the wrong place it applies cleanly and does nothing.
> - **Unquoted `true` / `false`.** Label values are strings; a YAML boolean is rejected by the API server.
> - **Changing a namespace label and not restarting.** Injection is decided at pod creation. Without `kubectl rollout restart` the change has no visible effect.
> - **Both `istio-injection` and `istio.io/rev` on one namespace.** `istio-injection` wins silently and the workload attaches to the default control plane, not the revision you named.
> - **Removing a workload from the mesh under STRICT mTLS.** An un-injected pod has no workload certificate. If a `PeerAuthentication` requires STRICT mutual TLS, meshed callers will start refusing its connections — opting out is a policy decision, not just a resource saving.
> - **Assuming container count is the universal check.** It works in sidecar mode only; section 040's ambient pods stay at one container while fully meshed.

> *Pod label beats namespace in both directions, `istio-injection` beats `istio.io/rev` on the same namespace, and the pod label only counts if it is on the template.*

## Reference

- [Controlling the injection policy](https://istio.io/v1.30/docs/setup/additional-setup/sidecar-injection/#controlling-the-injection-policy) — Istio's own statement of the precedence.
- [Istio annotations and labels](https://istio.io/v1.30/docs/reference/config/annotations/) — the full set, including the traffic-capture exclusions.
- [Canary upgrades](https://istio.io/v1.30/docs/setup/upgrade/canary/) — where the revision label stops being theoretical.
- `kubectl explain deployment.spec.template.metadata.labels` — the field the webhook actually reads.
