# Solution Walkthrough

Mission debrief, astronaut. You opt the namespace in, set both pod template overrides, restart what still needs it, and prove that each of the three workloads ended up where it should.

---

## Step 1: Confirm the starting state

Check the namespace labels and the containers in each pod:

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

No injection label, and one container each. Now read the webhook that will make the decisions:

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

Two entries with selectors that complement each other. The first says "the namespace opted in, and the pod did not opt out". The second says "the namespace did not opt in, but the pod opted in". Together they cover all four combinations: that is the whole precedence rule, written as label selectors.

`obj:` is checked against the **Pod**. That is why the override has to be on the pod template.

---

## Step 2: Opt the namespace in

Label the namespace, then look at the pods:

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

Still one container each. The label is on and nothing happened, because injection is decided when a pod is *created*. These pods were stored before the webhook applied to them.

---

## Step 3: Set both overrides before restarting

Set the labels first and restart last. Otherwise you restart twice, and `logging-agent` briefly gets a sidecar it should never have had.

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

Look at the patch path: `spec`, then `template`, then `metadata`, then `labels`. That is the **pod template**. In YAML it looks like this:

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

Changing the template changes its hash, and that starts a rollout by itself. So those two Deployments are already being replaced.

The quotes around `"false"` matter. Kubernetes label values are always strings. An unquoted `false` in YAML is a boolean, and the API server rejects the object. That mistake, at least, fails loudly.

---

## Step 4: Restart the remaining workload

Only `notification-service` still needs a restart. The other two were restarted by their patches.

```sh
kubectl -n inject-demo rollout restart deployment notification-service
kubectl -n inject-demo rollout status deployment --timeout=180s
```

```text
deployment "notification-service" successfully rolled out
```

---

## Step 5: Check the result

Look at the containers in each pod:

```sh
kubectl -n inject-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                             CONTAINERS
batch-job-...                   batch-job,istio-proxy
logging-agent-...               logging-agent
notification-service-...        notification-service,istio-proxy
```

Three workloads, three different results, one namespace. Confirm the labels are on the pod templates:

```sh
for deployment_name in logging-agent batch-job; do
  echo -n "$deployment_name template: "
  kubectl -n inject-demo get deployment "$deployment_name" \
    -o jsonpath='{.spec.template.metadata.labels.sidecar\.istio\.io/inject}{"\n"}'
done
```

```text
logging-agent template: false
batch-job template: true
```

Then ask mission control which workloads it is serving:

```sh
istioctl proxy-status | grep inject-demo
```

```text
batch-job-...inject-demo              Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED   istiod-...
notification-service-...inject-demo   Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED   istiod-...
```

Two entries, not three. Counting containers tells you what the pod spec says. `proxy-status` tells you which workloads the control plane is actually serving. A workload in one list but not the other is a real problem.

---

## Step 6: Prove `batch-job` does not depend on the namespace

This step is optional, and it is the fastest way to feel the precedence rule. Remove the namespace label, restart `batch-job`, and check its containers:

```sh
kubectl label namespace inject-demo istio-injection-
kubectl -n inject-demo rollout restart deployment batch-job
kubectl -n inject-demo rollout status deployment batch-job --timeout=180s
kubectl -n inject-demo get pod -l app=batch-job -o jsonpath='{.items[0].spec.containers[*].name}{"\n"}'
```

```text
batch-job istio-proxy
```

It still has its sidecar: the second webhook entry matched on the pod label alone.

**Put the namespace label back before you submit**, because the grader requires it:

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

The grader checks that `inject-demo` carries `istio-injection=enabled` and not `istio.io/rev`, that exactly three Deployments exist and are ready, that the `notification-service` and `batch-job` pods have `istio-proxy` while `logging-agent` has exactly one container, and that both `sidecar.istio.io/inject` labels are on `spec.template.metadata.labels`. If it finds one on the Deployment's own metadata, it tells you so by name.

---

## Common Mistakes

*   **Putting the label on the Deployment's `metadata.labels`.** The manifest applies, nothing fails, and injection is unchanged. The grader spots this case and tells you to move it.
*   **Unquoted `true` or `false`.** A YAML boolean is not a valid label value; the API server rejects it.
*   **Labelling the namespace and stopping there.** Running pods keep one container forever. Something has to recreate them.
*   **Restarting before setting the overrides.** `logging-agent` gets a sidecar, then loses it on the second restart. The end state is right, but you did twice the work, and on a real cluster that is a real disruption.
*   **Deleting and recreating a Deployment.** The grader counts three Deployments by name; recreating one under another name fails.
*   **Adding `istio.io/rev` "to be explicit".** With `istio-injection` also present, `istio-injection` wins and the revision label is silently ignored. The grader rejects having both.
