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
istio-egressgateway    1/1     1            1           18s
istio-ingressgateway   1/1     1            1           18s
istiod                 1/1     1            1           30s
accessLogFile: /dev/stdout
```

The `demo` profile already turns on access logging, so `accessLogFile: /dev/stdout` is there before you change anything. `outboundTrafficPolicy` is missing, so the built-in default (`ALLOW_ANY`) applies. When that key appears later, you know your document took effect.

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

`components.egressGateways` is a **list**, and your list replaces the profile's list as a whole. Your list holds one entry, `istio-egressgateway` with `enabled: false`, so no egress gateway is rendered. A typo in the name does not cause an error either, so the render is the place to check what the install will keep.

Validate the file, and count the egress gateway objects in the rendered result:

```sh
istioctl validate -f istio-custom.yaml
istioctl manifest generate -f istio-custom.yaml | grep -c '^  name: istio-egressgateway$'
```

```text
"istio-custom.yaml" is valid
0
```

Zero egress gateway objects means the profile's `istio-egressgateway` will not be installed.

`istioctl validate` checks the schema. `istioctl manifest generate -f` shows the rendered result, and it is the stronger check: if your change is not in the rendered output, it did not take, whatever the reason.

---

## Step 4: Apply

```sh
istioctl install -f istio-custom.yaml -y
```

The output looks like this (shortened: the logo and the progress lines are left out):

```text
✔ Istio core installed ⛵️
✔ Istiod installed 🧠
✔ Ingress gateways installed 🛬
- Pruning removed resources  Removed apps/v1, Kind=Deployment/istio-egressgateway.istio-system.
  Removed /v1, Kind=Service/istio-egressgateway.istio-system.
  Removed /v1, Kind=ServiceAccount/istio-egressgateway-service-account.istio-system.
  Removed rbac.authorization.k8s.io/v1, Kind=RoleBinding/istio-egressgateway-sds.istio-system.
  Removed rbac.authorization.k8s.io/v1, Kind=Role/istio-egressgateway-sds.istio-system.
✔ Installation complete
```

Read the summary. "Egress gateways installed" is gone, and "Ingress gateways installed" is still there. The pruning step lists the five egress gateway objects that `istioctl install` removed, because your new document turns that component off. `profile: demo` kept the ingress gateway.

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
istio-egressgateway    0/1     0            0           23s
istio-ingressgateway   1/1     1            1           23s
istiod                 1/1     1            1           35s
100m
accessLogFile: /dev/stdout
defaultConfig:
  discoveryAddress: istiod.istio-system.svc:15012
--
outboundTrafficPolicy:
  mode: REGISTRY_ONLY
rootNamespace: istio-system
```

Right after the install, `istio-egressgateway` still shows `0/1` while Kubernetes removes its pod; a few seconds later it is gone from the list. Each change landed in a different place: a Deployment disappeared, a field on a pod spec changed, and `outboundTrafficPolicy` appeared in the ConfigMap next to `accessLogFile`.

Confirm that the workload still has its sidecar proxy, the `istio-proxy` container that Istio adds to each pod in the mesh. Istio 1.30 runs it as a native sidecar, an init container with `restartPolicy: Always`, so list the init containers too:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                                     INIT                     CONTAINERS
notification-service-76f869bb97-7rvzg   istio-init,istio-proxy   notification-service
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

The sidecar proxy refuses the external host. Its access log shows how:

```sh
kubectl -n mesh-demo logs deploy/notification-service -c istio-proxy --tail=2
```

```text
2026-10-09T23:51:21.206503Z	info	xdsproxy	connected to delta upstream XDS server: istiod.istio-system.svc:15012	id=2
[2026-10-09T23:51:21.738Z] "GET / HTTP/1.1" 502 - direct_response - "-" 0 0 0 - "-" "Wget" "55417530-b84d-9444-8e6a-43e83a6db871" "example.com" "-" - - 104.20.23.154:80 10.244.0.8:52774 - block_all
```

The proxy answered `502` itself (`direct_response`), from the route named `block_all`, and sent nothing on. The response flag field is `-`, because no upstream connection failed. `REGISTRY_ONLY` blocks every destination that is not in the mesh registry, the list of services Istio knows about: a host that is not a Kubernetes Service and was not added with a `ServiceEntry` is refused. That is the setting working, not the mesh breaking.

---

## Step 7: Submit

```sh
astrona submit
```

The grader checks that no egress gateway Deployment exists anywhere, that `istio-ingressgateway` is still ready, that `istiod` requests `100m` CPU, that both `accessLogFile: /dev/stdout` and `REGISTRY_ONLY` are in the live mesh ConfigMap, and that `mesh-demo` is still labelled with a running, ready pod that has its `istio-proxy`.

---

## Common mistakes

*   **Switching to `minimal` to drop the egress gateway.** It drops the ingress gateway too, and the grader checks for it. Change one component of `demo` instead.
*   **Adding a gateway entry and expecting the others to stay.** A gateway list in your document replaces the profile's list. If you list a new ingress gateway and leave out `istio-ingressgateway`, the install deletes `istio-ingressgateway`, and the grader checks for it. `istioctl manifest generate -f` shows which gateways remain.
*   **Indenting `meshConfig` under `components`.** Misplaced keys become unknown fields and are ignored. The install succeeds and the ConfigMap is unchanged.
*   **Applying with `--set` only.** It passes, but it leaves no file behind. The next person has no idea what the cluster should look like, and the next install reverts it.
*   **Expecting external traffic to keep working.** `REGISTRY_ONLY` blocks outbound traffic by default. On a real cluster, list your outbound dependencies before you turn it on.
*   **Trusting `istioctl validate` alone.** It checks the schema, not whether your change matched anything. `istioctl manifest generate -f` is the check that shows what your lists really render.
