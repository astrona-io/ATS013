# Solution Walkthrough

Read this only after you have tried the specification yourself. It is an integration lab: the value is in working out the order on your own.

---

## Step 1: Plan before you type

The specification has four groups of requirements, and three of them depend on each other:

*   **The chart order is fixed.** `base` defines the CRDs (Custom Resource Definitions), `istiod` creates objects of those kinds, and the gateway is an xDS client with nothing to do until the control plane exists.
*   **Two settings land in two different places.** `meshConfig.*` ends up in the `istio` ConfigMap. `global.proxy.resources.*` ends up on each *injected sidecar*. You can only see the second one after a pod is injected, so the onboarding step is also the test of the values file.
*   **Injection happens when a pod is created.** `checkout-api` and `batch-runner` are both already running. Whatever you do to namespace labels, `payments` needs a restart, and `legacy` must be left alone.

A good order: namespaces, then `base`, `istiod`, the gateway, then onboard `payments`, then verify.

---

## Step 2: Namespaces

```sh
kubectl create namespace istio-system
kubectl create namespace edge
```

Neither chart creates its own namespace. `payments` and `legacy` already exist.

---

## Step 3: The values file

Write it first. It carries four of the requirements, and it is the file you would commit.

Save this as `istiod-values.yaml`:

```yaml
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
```

The three top-level keys have three different audiences:

*   **`meshConfig`** is mesh-wide behaviour. The chart writes it into the `istio` ConfigMap under the `mesh` key.
*   **`pilot`** is the control plane workload itself. `pilot` is the old name of the component that became `istiod`. With `autoscaleEnabled: false`, the chart creates no HorizontalPodAutoscaler.
*   **`global.proxy`** is the standard kit for **every injected sidecar**. Its cost multiplies: `10m` CPU here is `10m` for each meshed pod, not `10m` in total.

`ALLOW_ANY` is already the default for `outboundTrafficPolicy`, so writing it down changes nothing in behaviour. It is in the specification because writing a default down on purpose is a good habit. The other choice, `REGISTRY_ONLY`, blocks every destination the mesh does not know about, and the file should say which one you chose.

---

## Step 4: Install the three releases

Apply the file as part of the `istiod` install:

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

Three details matter here:

*   **`--version 1.30.5` on all three.** The grader checks the `istiod` image version, and an install without a pin is a different Istio next month.
*   **`--set defaultRevision=default` on `base`.** Without it, a namespace labelled `istio-injection=enabled` can find no webhook willing to serve it, and injection fails in a way that looks nothing like its cause.
*   **`--set service.type=NodePort` on the gateway.** The gateway chart uses `LoadBalancer` by default, which stays `<pending>` forever on `kind`. The specification asks for `NodePort`, and the grader reads the Service's `spec.type`.

The release name `public-gateway` becomes the Deployment name, the Service name and the pod labels. Get it wrong, and every later `Gateway` resource that selects the workload by label selects nothing.

---

## Step 5: Onboard `payments`, and leave `legacy` alone

```sh
kubectl label namespace payments istio-injection=enabled
kubectl -n payments rollout restart deployment checkout-api
kubectl -n payments rollout status deployment checkout-api --timeout=180s
```

```text
namespace/payments labeled
deployment "checkout-api" successfully rolled out
```

The restart is the step that brings in the sidecar. The label alone changes nothing for a pod that was created before the webhook applied to its namespace.

`legacy` needs **no action at all**. That is why it is in the task: the right answer to "this must stay out of the mesh" is to leave it untouched. The grader checks that `legacy` carries neither `istio-injection` nor `istio.io/rev`, and that `batch-runner`'s pod still has exactly one container.

---

## Step 6: Verify every requirement

Check the releases and the control plane:

```sh
helm ls -A
```

```text
NAME             NAMESPACE      REVISION  STATUS    CHART           APP VERSION
istio-base       istio-system   1         deployed  base-1.30.5     1.30.5
istiod           istio-system   1         deployed  istiod-1.30.5   1.30.5
public-gateway   edge           1         deployed  gateway-1.30.5  1.30.5
```

Check the live mesh-wide settings:

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

Check the gateway:

```sh
kubectl -n edge get svc public-gateway -o jsonpath='{.spec.type}{"\n"}'
kubectl get deployments -A | grep -i egress || echo "no egress gateway"
```

```text
NodePort
no egress gateway
```

Check the sidecar defaults. People miss this requirement, because you can only see it on an injected pod:

```sh
kubectl -n payments get pod -l app=checkout-api \
  -o jsonpath='{.items[0].spec.containers[?(@.name=="istio-proxy")].resources.requests}{"\n"}'
```

```text
{"cpu":"10m","memory":"64Mi"}
```

If that comes back empty or with other values, `global.proxy.resources` did not take effect. Most often it was passed as `--set` on the *gateway* release, or put under the wrong key.

Check both namespaces side by side:

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

Check the versions:

```sh
istioctl version
```

```text
client version: 1.30.5
control plane version: 1.30.5
data plane version: 1.30.5 (2 proxies)
```

Two proxies: `checkout-api`'s sidecar and the gateway. `batch-runner` is rightly missing.

---

## Step 7: Submit

```sh
astrona submit
```

---

## Common mistakes

*   **Using `istioctl install` to save time.** There are no Helm release Secrets afterwards, so the first check fails. It also gives the cluster two owners.
*   **Leaving the gateway Service as `LoadBalancer`.** It shows `<pending>` on `kind` and looks broken, but the real failure is that the specification asked for `NodePort`.
*   **Putting `global.proxy.resources` in the wrong release.** It belongs in the **`istiod`** values file, because `istiod` holds the injection template. On the gateway release it does nothing for sidecars.
*   **Checking the values file against itself.** `helm get values` shows what you *passed*. The `istio` ConfigMap and the injected pod show what the cluster really runs. Check those.
*   **"Helping" `legacy` by labelling it.** The specification says it stays out. A label and a restart put it in the mesh, and the grader fails on the extra sidecar.
*   **Deleting and recreating `checkout-api` instead of restarting it.** The grader counts the Deployments in `payments` and checks that the Service is still there.
*   **Forgetting the gateway in the version check.** A gateway is a proxy. If you reinstalled the control plane at another version after installing the gateway, the grader catches the mismatch.
