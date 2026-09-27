# Solution Walkthrough

Read this only after you have attempted the specification. It is an integration challenge — the value is in working out the order yourself.

---

## Step 1: Plan Before Typing

The specification has four clusters of requirements, and three of them constrain each other:

*   **Chart order is fixed.** `base` defines the CRDs, `istiod` creates objects of those kinds, the gateway is an xDS client with nothing to do until the control plane exists.
*   **Two settings land in two different places.** `meshConfig.*` ends up in the `istio` ConfigMap; `global.proxy.resources.*` ends up on each *injected sidecar*. The second one is only observable after a pod is injected, which means the onboarding step is also the test of the values file.
*   **Injection happens at pod creation.** Both `checkout-api` and `batch-runner` are already running, so whatever you do to namespace labels, `payments` needs a restart and `legacy` needs to be left alone.

A useful order: namespaces → base → istiod → gateway → onboard `payments` → verify.

---

## Step 2: Namespaces

```sh
kubectl create namespace istio-system
kubectl create namespace edge
```

Neither chart creates its own namespace. `payments` and `legacy` already exist.

---

## Step 3: The Values File

Write it first — it carries four of the specification's requirements and it is the artifact you would commit:

```sh
cat > istiod-values.yaml <<'YAML'
meshConfig:
  accessLogFile: /dev/stdout
  outboundTrafficPolicy:
    mode: ALLOW_ANY
pilot:
  autoscaleEnabled: false
global:
  proxy:
    resources:
      requests:
        cpu: 10m
        memory: 64Mi
YAML
```

Three top-level keys, three different audiences:

*   **`meshConfig`** — mesh-wide runtime behaviour, rendered into the `istio` ConfigMap under the `mesh` key.
*   **`pilot`** — the control-plane workload itself. `pilot` is the historical name of the component that became `istiod`. `autoscaleEnabled: false` means the chart creates no HPA.
*   **`global.proxy`** — defaults applied to **every injected sidecar**. This is the one whose cost multiplies: 10m CPU here is 10m per meshed pod, not 10m total.

`ALLOW_ANY` is the default for `outboundTrafficPolicy`, so setting it explicitly changes nothing functionally. It is in the specification because writing a default down deliberately is a real habit — the alternative, `REGISTRY_ONLY`, blocks every destination not in the mesh registry, and you want the file to say which posture you chose.

---

## Step 4: Install the Three Releases

```sh
helm install istio-base istio/base -n istio-system \
  --version 1.30.5 --set defaultRevision=default --wait

helm install istiod istio/istiod -n istio-system \
  --version 1.30.5 -f istiod-values.yaml --wait

helm install public-gateway istio/gateway -n edge \
  --version 1.30.5 --set service.type=NodePort --wait
```

```text
NAME: istio-base
STATUS: deployed
...
NAME: istiod
STATUS: deployed
...
NAME: public-gateway
STATUS: deployed
```

Three things worth naming:

*   `--version 1.30.5` on all three. The grader checks the `istiod` image tag, and an unpinned install is a different Istio next month.
*   `--set defaultRevision=default` on `base`. Without it, a namespace labelled `istio-injection=enabled` can find no webhook willing to serve it, and injection fails in a way that looks nothing like its cause.
*   `--set service.type=NodePort` on the gateway. The gateway chart defaults to `LoadBalancer`, which stays `<pending>` forever on kind. The specification asks for `NodePort`, and the grader reads `service.spec.type`.

The release name `public-gateway` becomes the Deployment name, the Service name and the pod labels. Get it wrong and every later `Gateway` resource that selects the workload by label selects nothing.

---

## Step 5: Onboard `payments`, and Leave `legacy` Alone

```sh
kubectl label namespace payments istio-injection=enabled
kubectl -n payments rollout restart deployment checkout-api
kubectl -n payments rollout status deployment checkout-api --timeout=180s
```

```text
namespace/payments labeled
deployment "checkout-api" successfully rolled out
```

The restart is the step that performs the injection. The label alone changes nothing for a pod that was admitted before the webhook applied to its namespace.

`legacy` needs **no action at all**. That is the point of including it: the correct response to "this must stay out of the mesh" is to not touch it. The grader checks that `legacy` carries neither `istio-injection` nor `istio.io/rev`, and that `batch-runner`'s pod still has exactly one container.

---

## Step 6: Verify Every Requirement

Releases and control plane:

```sh
helm ls -A
```

```text
NAME             NAMESPACE      REVISION  STATUS    CHART           APP VERSION
istio-base       istio-system   1         deployed  base-1.30.5     1.30.5
istiod           istio-system   1         deployed  istiod-1.30.5   1.30.5
public-gateway   edge           1         deployed  gateway-1.30.5  1.30.5
```

Mesh-wide settings, live:

```sh
kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep -A2 -E 'accessLogFile|outboundTrafficPolicy'
kubectl -n istio-system get hpa
```

```text
accessLogFile: /dev/stdout
outboundTrafficPolicy:
  mode: ALLOW_ANY

No resources found in istio-system namespace.
```

The gateway:

```sh
kubectl -n edge get svc public-gateway -o jsonpath='{.spec.type}{"\n"}'
kubectl get deployments -A | grep -i egress || echo "no egress gateway"
```

```text
NodePort
no egress gateway
```

The sidecar defaults — this is the requirement people miss, because it is only visible on an injected pod:

```sh
kubectl -n payments get pod -l app=checkout-api \
  -o jsonpath='{.items[0].spec.containers[?(@.name=="istio-proxy")].resources.requests}{"\n"}'
```

```text
{"cpu":"10m","memory":"64Mi"}
```

If that comes back empty or with different values, `global.proxy.resources` did not take effect — most often because it was passed as a `--set` on the *gateway* release, or nested under the wrong key.

Both namespaces, side by side:

```sh
kubectl -n payments get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
kubectl -n legacy get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                             CONTAINERS
checkout-api-7d4b9f6a21-k2vnm   checkout-api,istio-proxy

POD                             CONTAINERS
batch-runner-5b7d9c4f88-x9plm   batch-runner
```

Versions:

```sh
istioctl version
```

```text
client version: 1.30.5
control plane version: 1.30.5
data plane version: 1.30.5 (2 proxies)
```

Two proxies: `checkout-api`'s sidecar and the gateway. `batch-runner` is correctly absent.

---

## Step 7: Submit

```sh
astrona submit
```

---

## Common Mistakes

*   **Using `istioctl install` for speed.** There are no Helm release Secrets afterwards, so the first check fails outright. It is also the two-owners problem the section warns about.
*   **Leaving the gateway Service as `LoadBalancer`.** It comes up `<pending>` on kind and looks broken, but the real failure is that the specification asked for `NodePort`.
*   **Putting `global.proxy.resources` in the wrong release.** It belongs in the **`istiod`** values file, because that is what configures the injection template. On the gateway release it does nothing for sidecars.
*   **Verifying the values file against the file.** `helm get values` shows what you *passed*. The `istio` ConfigMap and the injected pod show what the cluster is actually running — check those.
*   **"Helping" `legacy` by labelling it.** The specification says it stays out. Adding a label and restarting meshes it, and the grader fails on the extra sidecar.
*   **Deleting and recreating `checkout-api` instead of restarting it.** The grader counts Deployments in `payments` and checks the Service is still there.
*   **Forgetting the gateway in the version check.** A gateway is a proxy. If you reinstalled the control plane at a different version after installing the gateway, the grader catches the mismatch.
