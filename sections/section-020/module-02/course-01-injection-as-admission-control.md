# Part 1 — Injection As Admission Control

> Prerequisite: [the module landing page](./course.md). Next: [Part 2 — The Precedence Rules](./course-02-the-precedence-rules.md).

Injection is not an Istio feature bolted onto Kubernetes; it is a standard Kubernetes extension point that Istio registers a handler for. Once you have the admission path in your head, the two rules that trip everyone up stop being facts to memorise and become things you can derive. This part builds that path.

## The path a pod takes

```text
  kubectl apply (Deployment)
        │
        ▼
  Deployment controller  ──creates──►  ReplicaSet  ──creates──►  Pod object
        │
        ▼
  API SERVER
   ├─ authentication
   ├─ authorization
   ├─ MUTATING ADMISSION  ◄── Istio's webhook lives here
   │     │
   │     ├─ does the webhook's selector match this pod / its namespace?
   │     │        no ──► skip
   │     │       yes
   │     ▼
   │   POST the pod object to istiod's /inject endpoint
   │     │
   │     ▼
   │   istiod returns a JSON patch:
   │     + container  istio-proxy
   │     + initContainer  istio-init      (or nothing, with CNI — see Part 3)
   │     + volumes, env vars, annotations
   │     ▼
   │   API server applies the patch to the object
   │
   ├─ VALIDATING ADMISSION
   └─ persist to etcd
        │
        ▼
  kubelet starts whatever was persisted
```

Two structural facts fall out of that, and between them they cover most injection questions.

**The webhook is called for Pods, not Deployments.** Istio's handler is registered against the `pods` resource on the `CREATE` operation. It never sees your Deployment. That is why every label that influences injection has to be somewhere the *pod* carries it — the topic of Part 2.

**The decision happens once, when the pod is created.** Mutating admission runs between the object being submitted and being stored. There is no controller watching for namespaces that became eligible later, because admission is not a reconciliation loop. A pod that was stored without a sidecar will never grow one; the only way to change its status is to replace it.

## The two webhook entries

Istio registers one `MutatingWebhookConfiguration` — `istio-sidecar-injector` — containing **two** webhook entries. Both point at the same `istiod` endpoint; what differs is the selector that decides when each fires.

| Entry | Fires when | Purpose |
| --- | --- | --- |
| `namespace.sidecar-injector.istio.io` | the **namespace** carries an injection label | The namespace-level opt-in |
| `object.sidecar-injector.istio.io` | the **pod** carries `sidecar.istio.io/inject: "true"` | The per-workload override, in a namespace that has not opted in |

That split is the mechanism behind "a pod label can force injection in an unlabelled namespace". It is not a special case inside `istiod`; it is a second webhook entry with a different selector. Kubernetes evaluates both, and a match on either sends the pod to `istiod`.

Two selector fields do the work:

- **`namespaceSelector`** — a label selector evaluated against the *namespace object*. This is the mechanical reason the namespace label exists.
- **`objectSelector`** — a label selector evaluated against the *pod being admitted*.

> [!TIP]
> **Try it — read the selectors the webhook enforces**
>
> ```sh
> kubectl get mutatingwebhookconfiguration istio-sidecar-injector \
>   -o jsonpath='{range .webhooks[*]}{"── "}{.name}{"\n  resources: "}{.rules[0].resources}{"\n  operations: "}{.rules[0].operations}{"\n  nsSelector: "}{.namespaceSelector}{"\n  objSelector: "}{.objectSelector}{"\n\n"}{end}'
> ```
>
> Expect something like:
>
> ```text
> ── namespace.sidecar-injector.istio.io
>   resources: ["pods"]
>   operations: ["CREATE"]
>   nsSelector: {"matchExpressions":[{"key":"istio-injection","operator":"In","values":["enabled"]},...]}
>   objSelector: {"matchExpressions":[{"key":"sidecar.istio.io/inject","operator":"NotIn","values":["false"]}]}
>
> ── object.sidecar-injector.istio.io
>   resources: ["pods"]
>   operations: ["CREATE"]
>   nsSelector: {"matchExpressions":[{"key":"istio-injection","operator":"NotIn","values":["enabled"]},...]}
>   objSelector: {"matchExpressions":[{"key":"sidecar.istio.io/inject","operator":"In","values":["true"]}]}
> ```
>
> `resources: ["pods"]` and `operations: ["CREATE"]` are the two facts everything else follows from. Read the two entries as a pair: the first says "namespace opted in, and the pod did not opt out"; the second says "namespace did not opt in, but the pod opted in". Between them they cover the four combinations, and Part 2 turns that into a decision table.

## The starting state, and why nothing has a sidecar

With the selectors in hand, the playground's opening state is predictable rather than something to discover. `inject-demo` was created with no injection label at all, so neither webhook entry can match: the namespace has not opted in, and no pod template carries `sidecar.istio.io/inject: "true"`. Checking it is worth thirty seconds, because it establishes that "one container per pod" is the *expected* state here and not a fault — and because every later step is measured against it.

> [!TIP]
> **Try it — confirm the namespace does not match**
>
> ```sh
> kubectl get ns inject-demo --show-labels
> kubectl -n inject-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
> ```
>
> Expect something like:
>
> ```text
> NAME          STATUS   AGE    LABELS
> inject-demo   Active   4m2s   kubernetes.io/metadata.name=inject-demo
>
> POD                        CONTAINERS
> batch-job-...              batch-job
> logging-agent-...          logging-agent
> notification-service-...   notification-service
> ```
>
> The only label is the one Kubernetes adds automatically. Neither webhook entry matches — no namespace opt-in and no pod-level `"true"` — so `istiod` is never consulted and all three pods have exactly one container.

## Labelling, and why it appears to do nothing

Adding `istio-injection=enabled` to the namespace makes the first webhook entry match. For pods created from that moment on.

> [!TIP]
> **Try it — label the namespace and watch nothing change**
>
> ```sh
> kubectl label namespace inject-demo istio-injection=enabled
> kubectl -n inject-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
> ```
>
> Expect something like:
>
> ```text
> namespace/inject-demo labeled
>
> POD                        CONTAINERS
> batch-job-...              batch-job
> logging-agent-...          logging-agent
> notification-service-...   notification-service
> ```
>
> The label is on and every pod still has one container. This is not a delay, and waiting will not fix it — those pods were admitted before the webhook applied to them, and admission is a one-time event per object.

Recreating the pods is what completes the change. `kubectl rollout restart deployment` is the right tool: it replaces pods through the Deployment controller, gradually, so the service stays up while the new pods go through admission.

> [!TIP]
> **Try it — restart, and watch the mesh appear**
>
> ```sh
> kubectl -n inject-demo rollout restart deployment notification-service logging-agent batch-job
> kubectl -n inject-demo rollout status deployment notification-service --timeout=120s
> kubectl -n inject-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
> ```
>
> Expect something like:
>
> ```text
> POD                        CONTAINERS
> batch-job-...              batch-job,istio-proxy
> logging-agent-...          logging-agent,istio-proxy
> notification-service-...   notification-service,istio-proxy
> ```
>
> All three now carry `istio-proxy` — including the two that should not. The namespace label is a blunt instrument that applies to everything in the namespace, which is exactly why the per-workload overrides in Part 2 exist.

## What happens when the webhook cannot be reached

The webhook configuration carries a `failurePolicy`, and Istio sets it to `Fail`. That means if the API server cannot reach `istiod`, pod creation in a matching namespace is **rejected** rather than silently proceeding without a sidecar.

That is the right default — silently un-injected pods in a mesh enforcing STRICT mTLS would be worse — but it has a consequence worth knowing before it happens at 3am: a control plane outage does not just stop configuration updates, it stops pods from starting in every injected namespace. Existing pods keep running; new ones cannot be scheduled.

This is also why a stale webhook configuration left over from a removed install is so disruptive, and why `istioctl x precheck` looks for exactly that.

> *The webhook fires on Pod CREATE only, selected by namespace or by pod label — every injection surprise is a consequence of those two words.*

## Reference

- [Installing the sidecar](https://istio.io/v1.30/docs/setup/additional-setup/sidecar-injection/) — Istio's own description of the automatic injection path.
- [Dynamic admission control](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/) — `namespaceSelector`, `objectSelector`, `failurePolicy` and the rest of the extension point.
- [Admission webhook good practices](https://kubernetes.io/docs/concepts/cluster-administration/admission-webhooks-good-practices/) — why `failurePolicy: Fail` has the blast radius it does.
- `kubectl explain mutatingwebhookconfiguration.webhooks` — the field reference for what you just read out of the cluster.
