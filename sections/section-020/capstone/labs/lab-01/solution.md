# Solution Walkthrough

Read this only after you have tried the specification yourself, astronaut.

---

## Step 1: Sort the requirements by layer

There are five control plane requirements, and they do not all live in the same place. Getting this map right before you type is most of the challenge:

| Requirement | Layer | Where it shows up |
| --- | --- | --- |
| Remove the egress gateway | `spec.components.egressGateways` | A Deployment disappears |
| Keep the ingress gateway | `spec.profile: demo` (inherited) | A Deployment stays |
| `istiod` at 250m / 512Mi | `spec.components.pilot.k8s.resources` | A field on the `istiod` pod spec |
| Access logging, `REGISTRY_ONLY` | `spec.meshConfig` | The `istio` ConfigMap |
| **Sidecars** default to 20m | `spec.values.global.proxy.resources` | A field on every **injected** pod |

The last row separates people who know the layers from people who match patterns. `components.pilot` sizes the control plane: one Deployment. `values.global.proxy` sizes every sidecar, the standard kit every communications officer is issued, multiplied by every meshed pod. They look alike and configure completely different things.

---

## Step 2: Write the document

Save this as `istio-custom.yaml`:

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: demo
  components:
    egressGateways:
      - name: istio-egressgateway
        enabled: false
    pilot:
      k8s:
        resources:
          requests:
            cpu: 250m
            memory: 512Mi
  meshConfig:
    accessLogFile: /dev/stdout
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
  values:
    global:
      proxy:
        resources:
          requests:
            cpu: 20m
```

Check that it renders the way you think before you apply it:

```sh
istioctl validate -f istio-custom.yaml
istioctl manifest generate -f istio-custom.yaml | grep -c '^  name: istio-egressgateway$'
```

`istioctl validate` checks the schema. `istioctl manifest generate -f` shows the rendered result, and it is the stronger check: a list `name` that matches nothing, or a key in the wrong place, is accepted silently, and only the rendered output shows it. A count of `0` egress gateway objects means your entry matched the profile's gateway.

---

## Step 3: Apply

```sh
istioctl install -f istio-custom.yaml -y
```

```text
✔ Istio core installed
✔ Istiod installed
✔ Ingress gateways installed
✔ Installation complete
```

"Egress gateways installed" is missing and "Ingress gateways installed" is there. `istioctl install` removed exactly the component your document turned off, while `profile: demo` kept the other one.

---

## Step 4: Set the injection override, then restart

Order matters: set the exclusion first, so `audit-shipper` never briefly gets a sidecar. Then label the namespace and restart `checkout-api`:

```sh
kubectl -n payments patch deployment audit-shipper -p \
  '{"spec":{"template":{"metadata":{"labels":{"sidecar.istio.io/inject":"false"}}}}}'

kubectl label namespace payments istio-injection=enabled

kubectl -n payments rollout restart deployment checkout-api
kubectl -n payments rollout status deployment --timeout=180s
```

```text
deployment.apps/audit-shipper patched
namespace/payments labeled
deployment "checkout-api" successfully rolled out
```

The patch path is `spec`, `template`, `metadata`, `labels`: the **pod template**. Istio's webhook is called for Pods and never sees the Deployment, so the same label on the Deployment's own `metadata.labels` applies cleanly and does nothing. The grader spots that mistake and names it.

`legacy` needs **no action at all**. The right answer to "this must stay outside the mesh" is to leave it alone: no label, no restart, nothing.

---

## Step 5: Check each layer where it lands

Start with the control plane:

```sh
kubectl -n istio-system get deploy
kubectl -n istio-system get deploy istiod \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests}{"\n"}'
kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep -A2 -E 'accessLogFile|outboundTrafficPolicy'
```

```text
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
istio-ingressgateway   1/1     1            1           11m
istiod                 1/1     1            1           11m

{"cpu":"250m","memory":"512Mi"}

accessLogFile: /dev/stdout
outboundTrafficPolicy:
  mode: REGISTRY_ONLY
```

The sidecar default can only be seen on an injected pod:

```sh
kubectl -n payments get pod -l app=checkout-api \
  -o jsonpath='{.items[0].spec.containers[?(@.name=="istio-proxy")].resources.requests.cpu}{"\n"}'
```

```text
20m
```

If that shows something else, `values.global.proxy.resources` did not take effect. The usual cause is writing it under `components.pilot.k8s` instead, which sized `istiod` twice and the sidecars not at all.

Then the injection result:

```sh
kubectl -n payments get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
kubectl -n legacy get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
kubectl get ns legacy --show-labels
```

```text
POD                           CONTAINERS
audit-shipper-...             audit-shipper
checkout-api-...              checkout-api,istio-proxy

POD                           CONTAINERS
nightly-report-...            nightly-report

NAME     STATUS   AGE   LABELS
legacy   Active   13m   kubernetes.io/metadata.name=legacy
```

Three workloads, three results, and `legacy` with no mesh label at all.

---

## Step 6: Submit

```sh
astrona submit
```

---

## Common Mistakes

*   **Putting the sidecar CPU request under `components.pilot.k8s`.** It sizes `istiod`, not the proxies. The grader reads the request from the injected `istio-proxy` container, which still carries the profile default.
*   **Switching to `minimal` to drop the egress gateway.** It drops the ingress gateway too. Change one component of `demo` instead.
*   **`sidecar.istio.io/inject` on the Deployment's own metadata.** It applies cleanly and does nothing. The grader spots this case.
*   **Labelling `legacy` "to be consistent".** The specification says it stays out, and the grader rejects `istio-injection`, `istio.io/rev` and `istio.io/dataplane-mode` on it.
*   **Labelling `payments` before excluding `audit-shipper`.** It works if you restart twice, but the shipper gets a sidecar in between: a real disruption on a real cluster.
*   **Forgetting that `checkout-api` needs a restart.** The namespace label does nothing for a pod that already exists.
*   **Deleting and recreating a Deployment.** The grader counts two Deployments in `payments` and checks that the `checkout-api` Service is still there.
