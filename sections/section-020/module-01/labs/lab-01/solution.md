# Solution Walkthrough

Follow these steps to write an [`IstioOperator`](https://istio.io/v1.30/docs/reference/config/istio.operator.v1alpha1/) that deviates from `demo` in three layers and prove each change landed.

---

## Step 1: Read the Baseline First

```sh
kubectl -n istio-system get deploy
kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep -E 'accessLogFile|outboundTrafficPolicy' || echo '(neither key is present)'
```

```text
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
istio-egressgateway    1/1     1            1           3m
istio-ingressgateway   1/1     1            1           3m
istiod                 1/1     1            1           3m

(neither key is present)
```

Absence is meaningful. The stock `demo` profile sets neither `accessLogFile` nor `outboundTrafficPolicy`, so the built-in defaults apply. Those two keys appearing later is how you will know your document took effect.

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
            cpu: 100m
  meshConfig:
    accessLogFile: /dev/stdout
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
YAML
```

Three requirements, two layers:

*   **`spec.components`** decides *what is deployed and how big*. `egressGateways` removes a Deployment; `pilot.k8s.resources` changes a field on a pod template. `pilot` is the historical name of the component that became `istiod`, and `k8s:` is the fixed sub-key for Kubernetes-level settings.
*   **`spec.meshConfig`** decides *how the deployed things behave*. It ends up verbatim in the `istio` ConfigMap.

Keeping `profile: demo` is what preserves the ingress gateway. The document is a deviation *from* `demo`, not a replacement for it.

---

## Step 3: Check Before You Apply

`components.egressGateways` is a **list**, and entries are matched against the profile's entries by `name`. A typo does not error — it defines a *new*, disabled gateway and leaves the original running.

```sh
istioctl validate -f istio-custom.yaml
istioctl manifest generate -f istio-custom.yaml | grep -c '^  name: istio-egressgateway$'
```

```text
"istio-custom.yaml" is valid

    - enabled: false
      k8s:
        ...
      name: istio-egressgateway
```

One entry, `enabled: false`, under the name the profile actually uses. If the dump showed *two* egress gateway entries, one enabled and one not, the name is wrong.

`istioctl validate` checks the schema; `profile dump -f` shows the rendered result. The second is the stronger check — if your override is not in the dump, it did not take, whatever the reason.

---

## Step 4: Apply

```sh
istioctl install -f istio-custom.yaml -y
```

```text
✔ Istio core installed
✔ Istiod installed
✔ Ingress gateways installed
✔ Installation complete
```

Read the summary: "Egress gateways installed" is gone, "Ingress gateways installed" is still there. That is reconciliation removing a component your new document omits — the same mechanism that would delete *both* gateways if you had switched to `minimal`.

---

## Step 5: Verify Each Layer Where That Layer Lands

```sh
kubectl -n istio-system get deploy
kubectl -n istio-system get deploy istiod -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}{"\n"}'
kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep -A2 -E 'accessLogFile|outboundTrafficPolicy'
```

```text
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
istio-ingressgateway   1/1     1            1           9m
istiod                 1/1     1            1           9m

100m

accessLogFile: /dev/stdout
outboundTrafficPolicy:
  mode: REGISTRY_ONLY
```

Three layers, three different places the result shows up: a Deployment disappeared, a field on a pod spec changed, and two keys appeared in a ConfigMap.

Confirm the mesh still works:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                                     CONTAINERS
notification-service-6c8f9d7b5c-t7wqx   notification-service,istio-proxy
```

---

## Step 6: See `REGISTRY_ONLY` Do Something

Worth doing once, because this setting is the one people enable by accident:

```sh
kubectl -n mesh-demo exec deploy/notification-service -c notification-service -- \
  sh -c 'wget -qO- --timeout=5 http://example.com >/dev/null 2>&1; echo "exit=$?"'
```

```text
exit=1
```

The external host is refused by the sidecar. `REGISTRY_ONLY` blocks every destination that is not in the mesh registry — not a Kubernetes Service and not declared with a `ServiceEntry`. That is the setting working, not the mesh breaking.

---

## Step 7: Submit

```sh
astrona submit
```

The grader checks that no egress gateway Deployment exists anywhere, that `istio-ingressgateway` is still ready, that `istiod` requests `100m` CPU, that both `accessLogFile` and `REGISTRY_ONLY` are in the live mesh ConfigMap, and that `mesh-demo` is still labelled with a running injected pod.

---

## Common Mistakes

*   **Reaching for `minimal` to drop the egress gateway.** It drops the ingress gateway too, and the grader checks for it specifically. Override one component of `demo` instead.
*   **A typo in the component `name`.** `istio-egress-gateway` matches nothing in the profile, so Istio adds a second, disabled entry and leaves the original running. `istioctl manifest generate -f` still shows the original egress gateway objects.
*   **Indenting `meshConfig` under `components`.** Misplaced keys become unknown fields and are ignored. The install succeeds and the ConfigMap is unchanged.
*   **Applying with `--set` only.** It passes, and it leaves no artifact — so the next person has no idea what the cluster is supposed to look like, and the next install reverts it.
*   **Expecting external traffic to keep working.** `REGISTRY_ONLY` is deny-by-default for outbound. On a real cluster, inventory your outbound dependencies before enabling it.
*   **Assuming `istioctl validate` is enough.** It checks the schema, not whether your override matched anything. `profile dump -f` is the check that catches an unmatched list name.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [istioctl installation](https://istio.io/v1.30/docs/setup/install/istioctl/) — `istioctl install`, `--set`, and what the command actually applies
- [IstioOperator API](https://istio.io/v1.30/docs/reference/config/istio.operator.v1alpha1/) — every field the install API accepts
- [Configuration profiles](https://istio.io/v1.30/docs/setup/additional-setup/config-profiles/) — what each built-in profile turns on
- [Global mesh options](https://istio.io/v1.30/docs/reference/config/istio.mesh.v1alpha1/) — every mesh-wide setting and its default
- [istioctl command reference](https://istio.io/v1.30/docs/reference/commands/istioctl/) — every subcommand and flag
- [Installing gateways](https://istio.io/v1.30/docs/setup/additional-setup/gateway/) — deploying gateways separately from the control plane
