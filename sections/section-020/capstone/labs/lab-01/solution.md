# Solution Walkthrough

Read this only after you have attempted the specification.

---

## Step 1: Sort the Requirements by Layer

Five control-plane requirements, and they are not all in the same place. Getting this mapping right before you type is most of the challenge:

| Requirement | Layer | Where it shows up |
| --- | --- | --- |
| Remove the egress gateway | `spec.components.egressGateways` | A Deployment disappears |
| Keep the ingress gateway | `spec.profile: demo` (inherited) | A Deployment stays |
| `istiod` at 250m / 512Mi | `spec.components.pilot.k8s.resources` | A field on the `istiod` pod spec |
| Access logging, `REGISTRY_ONLY` | `spec.meshConfig` | The `istio` ConfigMap |
| **Sidecars** default to 20m | `spec.values.global.proxy.resources` | A field on every **injected** pod |

The last row is the one that separates people who know the layers from people who pattern-match. `components.pilot` sizes the control plane — one Deployment. `values.global.proxy` sizes every sidecar — multiplied by every meshed pod. They look similar and configure completely different things.

---

## Step 2: Write the Document

```sh
cat > istio-custom.yaml <<'YAML'
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
YAML
```

Check it renders the way you think before applying:

```sh
istioctl validate -f istio-custom.yaml
istioctl manifest generate -f istio-custom.yaml | grep -c '^  name: istio-egressgateway$'
```

`istioctl validate` checks the schema. `profile dump -f` shows the rendered result — the stronger check, because an unmatched list `name` or a misplaced key is accepted silently, and only the dump reveals it.

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

"Egress gateways installed" is absent and "Ingress gateways installed" is present. That is reconciliation removing exactly the component your document omitted, while `profile: demo` keeps the other one.

---

## Step 4: Set the Injection Overrides, Then Restart

Order matters here for the same reason as the module lab: set the exclusion first so `audit-shipper` never briefly gets a sidecar.

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

The patch path is `spec` → `template` → `metadata` → `labels`: the **pod template**. Istio's webhook is registered against Pods and never sees the Deployment, so the same label on the Deployment's own `metadata.labels` applies cleanly and does nothing. The grader detects that specific mistake and names it.

`legacy` needs **no action at all**. The correct response to "this must stay outside the mesh" is to leave it alone — no label, no restart, nothing.

---

## Step 5: Verify Each Layer Where It Lands

Control plane:

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

The sidecar default — only observable on an injected pod:

```sh
kubectl -n payments get pod -l app=checkout-api \
  -o jsonpath='{.items[0].spec.containers[?(@.name=="istio-proxy")].resources.requests.cpu}{"\n"}'
```

```text
20m
```

If that comes back as something else, `values.global.proxy.resources` did not take effect — most often because it was written under `components.pilot.k8s` instead, which sized `istiod` twice and the sidecars not at all.

The injection matrix:

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

Three workloads, three outcomes, and `legacy` with no mesh label at all.

---

## Step 6: Submit

```sh
astrona submit
```

---

## Common Mistakes

*   **Putting the sidecar CPU request under `components.pilot.k8s`.** It sizes `istiod`, not the proxies. The grader reads the request off the injected `istio-proxy` container, which will still carry the profile default.
*   **Switching to `minimal` to drop the egress gateway.** It drops the ingress gateway too. Override one component of `demo`.
*   **`sidecar.istio.io/inject` on the Deployment's own metadata.** Applies cleanly, does nothing. The grader detects this case specifically.
*   **Labelling `legacy` "for consistency".** The specification says it stays out, and the grader rejects `istio-injection`, `istio.io/rev` and `istio.io/dataplane-mode` on it.
*   **Labelling `payments` before excluding `audit-shipper`.** It works if you restart twice, but the shipper gets a sidecar in between — a real disruption on a real cluster.
*   **Forgetting `checkout-api` needs a restart.** The namespace label does nothing for a pod that already exists.
*   **Deleting and recreating a Deployment.** The grader counts two Deployments in `payments` by name, and checks the `checkout-api` Service is still there.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [istioctl installation](https://istio.io/v1.30/docs/setup/install/istioctl/) — `istioctl install`, `--set`, and what the command actually applies
- [IstioOperator API](https://istio.io/v1.30/docs/reference/config/istio.operator.v1alpha1/) — every field the install API accepts
- [Install with Helm](https://istio.io/v1.30/docs/setup/install/helm/) — the charts, their values, and install ordering
- [Configuration profiles](https://istio.io/v1.30/docs/setup/additional-setup/config-profiles/) — what each built-in profile turns on
- [Canary upgrades](https://istio.io/v1.30/docs/setup/upgrade/canary/) — revisions, revision labels and moving workloads between control planes
- [Sidecar injection](https://istio.io/v1.30/docs/setup/additional-setup/sidecar-injection/) — the namespace label, the pod annotation, and when injection happens
- [Global mesh options](https://istio.io/v1.30/docs/reference/config/istio.mesh.v1alpha1/) — every mesh-wide setting and its default
- [Istio annotations and labels](https://istio.io/v1.30/docs/reference/config/annotations/) — the reference list of both
- [istioctl command reference](https://istio.io/v1.30/docs/reference/commands/istioctl/) — every subcommand and flag
- [Installing gateways](https://istio.io/v1.30/docs/setup/additional-setup/gateway/) — deploying gateways separately from the control plane
