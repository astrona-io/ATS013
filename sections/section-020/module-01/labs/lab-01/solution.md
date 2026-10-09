# Solution Walkthrough

Follow these steps to write one `IstioOperator` file that changes the `demo` profile in three places, check it before you apply it, apply it, and prove that each change landed where its layer puts it.

---

## Step 1: Read the starting state first

List the Deployments in `istio-system`, and look for the two mesh settings in the `istio` ConfigMap:

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

The missing keys mean something. The built-in `demo` profile sets neither `accessLogFile` nor `outboundTrafficPolicy`, so the built-in defaults apply. When those two keys appear later, you know your document took effect.

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
            cpu: 100m
  meshConfig:
    accessLogFile: /dev/stdout
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
```

The document keeps `profile: demo` and changes two more layers:

*   **`spec.components`** decides *what is deployed and how big*. `egressGateways` removes a Deployment, and `pilot.k8s.resources` changes a field on a pod template. `pilot` is the old name of the component that became `istiod`, Istio's control plane, and `k8s:` is the fixed sub-key for Kubernetes settings.
*   **`spec.meshConfig`** decides *how the deployed things behave*. It ends up word for word in the `istio` ConfigMap.

Keeping `profile: demo` is what keeps the ingress gateway. The document is a change *to* `demo`, not a replacement for it.

---

## Step 3: Check before you apply

`components.egressGateways` is a **list**, and `istioctl` matches its entries against the profile's entries by `name`. A typo does not cause an error. It defines a *new*, disabled gateway and leaves the original running.

Validate the file, and count the egress gateway objects in the rendered result:

```sh
istioctl validate -f istio-custom.yaml
istioctl manifest generate -f istio-custom.yaml | grep -c '^  name: istio-egressgateway$'
```

```text
"istio-custom.yaml" is valid
0
```

Zero egress gateway objects means your entry matched the profile's `istio-egressgateway`. If the count is not zero, the name in your file is wrong.

`istioctl validate` checks the schema. `istioctl manifest generate -f` shows the rendered result, and it is the stronger check: if your change is not in the rendered output, it did not take, whatever the reason.

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

Read the summary. "Egress gateways installed" is gone, and "Ingress gateways installed" is still there. `istioctl install` removed the component your new document turns off, and `profile: demo` kept the other one.

---

## Step 5: Check each layer where it lands

Look at the Deployments, the CPU request of `istiod`, and the two mesh keys:

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

Each change landed in a different place: a Deployment disappeared, a field on a pod spec changed, and two keys appeared in a ConfigMap.

Confirm that the workload still has its sidecar proxy, the `istio-proxy` container that Istio adds to each pod in the mesh:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                                     CONTAINERS
notification-service-6c8f9d7b5c-t7wqx   notification-service,istio-proxy
```

---

## Step 6: See `REGISTRY_ONLY` do something

This step is optional, but worth doing once, because people often turn this setting on by accident. Try to reach a public website from the meshed workload:

```sh
kubectl -n mesh-demo exec deploy/notification-service -c notification-service -- \
  sh -c 'wget -qO- --timeout=5 http://example.com >/dev/null 2>&1; echo "exit=$?"'
```

```text
exit=1
```

The sidecar proxy refuses the external host. `REGISTRY_ONLY` blocks every destination that is not in the mesh registry, the list of services Istio knows about: a host that is not a Kubernetes Service and was not added with a `ServiceEntry` is refused. That is the setting working, not the mesh breaking.

---

## Step 7: Submit

```sh
astrona submit
```

The grader checks that no egress gateway Deployment exists anywhere, that `istio-ingressgateway` is still ready, that `istiod` requests `100m` CPU, that both `accessLogFile: /dev/stdout` and `REGISTRY_ONLY` are in the live mesh ConfigMap, and that `mesh-demo` is still labelled with a running, ready pod that has its `istio-proxy`.

---

## Common mistakes

*   **Switching to `minimal` to drop the egress gateway.** It drops the ingress gateway too, and the grader checks for it. Change one component of `demo` instead.
*   **A typo in the component `name`.** `istio-egress-gateway` matches nothing in the profile, so Istio adds a second, disabled entry and leaves the original running. `istioctl manifest generate -f` still shows the original egress gateway objects.
*   **Indenting `meshConfig` under `components`.** Misplaced keys become unknown fields and are ignored. The install succeeds and the ConfigMap is unchanged.
*   **Applying with `--set` only.** It passes, but it leaves no file behind. The next person has no idea what the cluster should look like, and the next install reverts it.
*   **Expecting external traffic to keep working.** `REGISTRY_ONLY` blocks outbound traffic by default. On a real cluster, list your outbound dependencies before you turn it on.
*   **Trusting `istioctl validate` alone.** It checks the schema, not whether your change matched anything. `istioctl manifest generate -f` is the check that catches a list name that matches nothing.
