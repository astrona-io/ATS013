# Solution Walkthrough

Follow these steps to produce the injection matrix: one namespace opted in, one workload pulled out, one forced in.

---

## Step 1: Confirm the Starting State

```sh
kubectl get ns inject-demo --show-labels
kubectl -n inject-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
NAME          STATUS   AGE    LABELS
inject-demo   Active   4m2s   kubernetes.io/metadata.name=inject-demo

POD                        CONTAINERS
batch-job-...              batch-job
logging-agent-...          logging-agent
notification-service-...   notification-service
```

No injection label, one container each. Worth reading the webhook that will make the decisions:

```sh
kubectl get mutatingwebhookconfiguration istio-sidecar-injector \
  -o jsonpath='{range .webhooks[*]}{.name}{"\n  ns: "}{.namespaceSelector}{"\n  obj: "}{.objectSelector}{"\n\n"}{end}'
```

```text
namespace.sidecar-injector.istio.io
  ns: {"matchExpressions":[{"key":"istio-injection","operator":"In","values":["enabled"]},...]}
  obj: {"matchExpressions":[{"key":"sidecar.istio.io/inject","operator":"NotIn","values":["false"]}]}

object.sidecar-injector.istio.io
  ns: {"matchExpressions":[{"key":"istio-injection","operator":"NotIn","values":["enabled"]},...]}
  obj: {"matchExpressions":[{"key":"sidecar.istio.io/inject","operator":"In","values":["true"]}]}
```

Two entries with complementary selectors. The first says "namespace opted in, and the pod did not opt out"; the second says "namespace did not opt in, but the pod opted in". Between them they cover the four combinations — which is the entire precedence rule, expressed as label selectors rather than as logic inside Istio.

Note `obj:` is evaluated against the **Pod**. That is why the override has to be on the pod template.

---

## Step 2: Opt the Namespace In

```sh
kubectl label namespace inject-demo istio-injection=enabled
kubectl -n inject-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
namespace/inject-demo labeled

POD                        CONTAINERS
batch-job-...              batch-job
logging-agent-...          logging-agent
notification-service-...   notification-service
```

Still one container each. The label is on and nothing happened, because injection is a mutating admission decision made when a pod is *created*. These pods were stored before the webhook applied to them.

---

## Step 3: Set Both Overrides Before Restarting

Do the labels first and the restart last — otherwise you restart twice, and `logging-agent` briefly gets a sidecar it should never have had.

```sh
kubectl -n inject-demo patch deployment logging-agent -p \
  '{"spec":{"template":{"metadata":{"labels":{"sidecar.istio.io/inject":"false"}}}}}'

kubectl -n inject-demo patch deployment batch-job -p \
  '{"spec":{"template":{"metadata":{"labels":{"sidecar.istio.io/inject":"true"}}}}}'
```

```text
deployment.apps/logging-agent patched
deployment.apps/batch-job patched
```

Look at the patch path carefully: `spec` → `template` → `metadata` → `labels`. That is the **pod template**. The equivalent YAML:

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

Patching the template changes the template hash, which triggers a rollout on its own — so those two Deployments are already being replaced.

The quotes around `"false"` matter. Kubernetes label values are always strings; an unquoted `false` in YAML is a boolean and the API server rejects the object outright. That one at least fails loudly.

---

## Step 4: Restart the Remaining Workload

Only `notification-service` still needs it — the other two were restarted by their patches.

```sh
kubectl -n inject-demo rollout restart deployment notification-service
kubectl -n inject-demo rollout status deployment --timeout=180s
```

```text
deployment "notification-service" successfully rolled out
```

---

## Step 5: Verify the Matrix

```sh
kubectl -n inject-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                             CONTAINERS
batch-job-...                   batch-job,istio-proxy
logging-agent-...               logging-agent
notification-service-...        notification-service,istio-proxy
```

Three workloads, three different outcomes, one namespace. Confirm the labels are where they need to be:

```sh
for d in logging-agent batch-job; do
  echo -n "$d template: "
  kubectl -n inject-demo get deployment "$d" \
    -o jsonpath='{.spec.template.metadata.labels.sidecar\.istio\.io/inject}{"\n"}'
done
```

```text
logging-agent template: false
batch-job template: true
```

And cross-check what Istio thinks is in the mesh:

```sh
istioctl proxy-status | grep inject-demo
```

```text
batch-job-...inject-demo              Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED   istiod-...
notification-service-...inject-demo   Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED   istiod-...
```

Two entries, not three. Counting containers tells you what the pod spec says; `proxy-status` tells you which workloads the control plane is actually serving. A workload in one list but not the other is a real problem.

---

## Step 6: Prove `batch-job` Does Not Depend on the Namespace

Optional, and the fastest way to feel the precedence rule. Remove the namespace label, restart `batch-job`, and check:

```sh
kubectl label namespace inject-demo istio-injection-
kubectl -n inject-demo rollout restart deployment batch-job
kubectl -n inject-demo rollout status deployment batch-job --timeout=180s
kubectl -n inject-demo get pod -l app=batch-job -o jsonpath='{.items[0].spec.containers[*].name}{"\n"}'
```

```text
batch-job istio-proxy
```

Still injected — the second webhook entry matched on the pod label alone.

**Put the namespace label back before submitting**, because the grader requires it:

```sh
kubectl label namespace inject-demo istio-injection=enabled
kubectl -n inject-demo rollout restart deployment notification-service
kubectl -n inject-demo rollout status deployment --timeout=180s
```

---

## Step 7: Submit

```sh
astrona submit
```

The grader checks that `inject-demo` carries `istio-injection=enabled` and not `istio.io/rev`, that exactly three Deployments exist and are ready, that `notification-service` and `batch-job` pods carry `istio-proxy` while `logging-agent` has exactly one container, and — specifically — that both `sidecar.istio.io/inject` labels are on `spec.template.metadata.labels`. If it finds one on the Deployment's own metadata it says so by name.

---

## Common Mistakes

*   **Putting the label on the Deployment's `metadata.labels`.** The manifest applies, nothing errors, and injection is unchanged. The grader detects this case and tells you to move it.
*   **Unquoted `true` / `false`.** A YAML boolean is not a valid label value; the API server rejects it.
*   **Labelling the namespace and stopping.** Existing pods keep one container forever. Something has to recreate them.
*   **Restarting before setting the overrides.** `logging-agent` gets a sidecar, then loses it on the second restart. The end state is right but you did twice the work — and on a real cluster that is a real disruption.
*   **Deleting and recreating a Deployment.** The grader counts three Deployments by name; recreating one under a different name fails.
*   **Adding `istio.io/rev` "to be explicit".** With `istio-injection` also present, `istio-injection` wins and the revision label is silently ignored. The grader rejects both being set.
