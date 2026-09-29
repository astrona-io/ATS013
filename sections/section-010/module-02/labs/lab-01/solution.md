# Solution Walkthrough

Follow these steps to install Istio as three Helm releases, put the gateway in its own namespace, and bring the existing workload into the mesh.

---

## Step 1: Confirm the Starting State

```sh
helm ls -A
kubectl get crd | grep -c istio.io || true
```

```text
NAME    NAMESPACE   REVISION    STATUS  CHART   APP VERSION

0
```

No releases, no CRDs. Check what the repository offers:

```sh
helm search repo istio --versions | head -6
```

```text
NAME            CHART VERSION   APP VERSION     DESCRIPTION
istio/base      1.30.5          1.30.5          Helm chart for deploying Istio cluster resources
istio/cni       1.30.5          1.30.5          Helm chart for Istio CNI components
istio/gateway   1.30.5          1.30.5          Helm chart for deploying Istio gateways
istio/istiod    1.30.5          1.30.5          Helm chart for istio control plane
istio/ztunnel   1.30.5          1.30.5          Helm chart for Istio ztunnel components
```

`CHART VERSION` and `APP VERSION` match, which is what makes `--version 1.30.5` a meaningful pin: that chart installs exactly that Istio.

---

## Step 2: Create the Namespaces

```sh
kubectl create namespace istio-system
kubectl create namespace edge
```

```text
namespace/istio-system created
namespace/edge created
```

Neither chart creates its namespace. `--create-namespace` would also work, but creating them explicitly is where labels and quotas would go on a real cluster.

The gateway lives in `edge` rather than `istio-system` on purpose: a gateway is an internet-facing workload with its own scaling and its own blast radius, while `istio-system` holds the control plane and the cluster's certificate authority. Separating them means you can let a team manage their gateway without giving them anything in `istio-system`.

---

## Step 3: Install `base` — Definitions First

```sh
helm install istio-base istio/base -n istio-system \
  --version 1.30.5 --set defaultRevision=default --wait
```

```text
NAME: istio-base
LAST DEPLOYED: ...
NAMESPACE: istio-system
STATUS: deployed
REVISION: 1
```

Three flags, three reasons:

*   `--version 1.30.5` pins the chart. Without it Helm installs whatever is newest in the repo right now, so the same command next month gives a different Istio.
*   `--wait` blocks until the release's resources are ready instead of returning when the API server accepts them. It is what stops a script racing ahead to the next chart.
*   `--set defaultRevision=default` tells the chart which control-plane revision owns the *unrevisioned* injection webhook. Skip it on a single-control-plane install and injection can silently fail later, with no webhook willing to serve a namespace labelled `istio-injection=enabled`.

```sh
kubectl get crd | grep -c istio.io
kubectl -n istio-system get pods
```

```text
15
No resources found in istio-system namespace.
```

A deployed release, a pile of CRDs, and zero pods. `base` is pure definitions — which is exactly why installing `istiod` first fails: the kinds it needs would not exist yet, and the API server rejects them with an error naming the missing resource.

---

## Step 4: Install `istiod` From a Values File

Write the file first, so the configuration is an artifact you could commit rather than a shell flag that exists only in your history:

```sh
cat > istiod-values.yaml <<'YAML'
meshConfig:
  accessLogFile: /dev/stdout
pilot:
  autoscaleEnabled: false
YAML
```

The two top-level keys do different jobs:

*   **`meshConfig`** is mesh-wide runtime behaviour. It is rendered verbatim into a ConfigMap named `istio` in `istio-system`, under a key called `mesh` — which is where you will verify it in Step 7.
*   **`pilot`** configures the control-plane workload itself. `pilot` is the historical name of the component that became `istiod`, which is why the key looks unfamiliar. Setting `autoscaleEnabled: false` means the chart creates no HorizontalPodAutoscaler.

```sh
helm install istiod istio/istiod -n istio-system \
  --version 1.30.5 -f istiod-values.yaml --wait
```

```text
NAME: istiod
STATUS: deployed
REVISION: 1
```

```sh
kubectl -n istio-system get deploy istiod
```

```text
NAME     READY   UP-TO-DATE   AVAILABLE   AGE
istiod   1/1     1            1           45s
```

---

## Step 5: Install the Gateway as Its Own Release

```sh
helm install public-gateway istio/gateway -n edge --version 1.30.5 --wait
```

```text
NAME: public-gateway
NAMESPACE: edge
STATUS: deployed
REVISION: 1
```

**The release name becomes the object name.** The chart derives the Deployment name, the Service name and the pod labels from it, so `public-gateway` here produces `deployment/public-gateway` and `service/public-gateway`. That is not cosmetic — a `Gateway` resource you write later selects a gateway workload *by its labels*, so the release name is part of the contract your traffic configuration depends on.

```sh
kubectl -n edge get deploy,svc
kubectl -n edge get deploy public-gateway -o jsonpath='{.spec.template.spec.containers[*].name}{"\n"}'
```

```text
NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/public-gateway   1/1     1            1           30s

NAME                     TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
service/public-gateway   LoadBalancer   10.96.148.22   <pending>     15021:31...,80:31...,443:31...

istio-proxy
```

One container, `istio-proxy` — the same Envoy image a sidecar runs, deployed standalone. `EXTERNAL-IP <pending>` is expected on kind, which has no cloud load balancer; the Service still works through its node ports.

Note there is no egress gateway, and the task forbids one. Nothing in the Helm path installs a gateway you did not ask for — that is a difference from the `demo` profile in Module 1, which installs both.

---

## Step 6: Bring the Workload Into the Mesh

```sh
kubectl label namespace mesh-demo istio-injection=enabled
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
namespace/mesh-demo labeled

POD                                     CONTAINERS
notification-service-6c8f9d7b5c-t7wqx   notification-service
```

Still one container — the same rule as Module 1. Injection is done by a mutating admission webhook that runs when a pod is *created*, and this pod was admitted before the webhook applied to its namespace.

```sh
kubectl -n mesh-demo rollout restart deployment notification-service
kubectl -n mesh-demo rollout status deployment notification-service --timeout=180s
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
deployment "notification-service" successfully rolled out

POD                                     CONTAINERS
notification-service-7d4b9f6a21-k2vnm   notification-service,istio-proxy
```

This is also the real end-to-end test of the install. Three releases reporting `deployed` only means Helm applied its manifests; a pod coming back with a container you did not ask for means the CRDs, the webhook configuration and the control plane behind it are all working together.

---

## Step 7: Verify

```sh
helm ls -A
```

```text
NAME             NAMESPACE      REVISION  STATUS    CHART           APP VERSION
istio-base       istio-system   1         deployed  base-1.30.5     1.30.5
istiod           istio-system   1         deployed  istiod-1.30.5   1.30.5
public-gateway   edge           1         deployed  gateway-1.30.5  1.30.5
```

```sh
kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep accessLogFile
kubectl -n istio-system get hpa
```

```text
accessLogFile: /dev/stdout
No resources found in istio-system namespace.
```

The `mesh` key in the `istio` ConfigMap is the **live** mesh configuration — not what you typed, but what the cluster is running. No HPA confirms `pilot.autoscaleEnabled: false` took effect.

```sh
istioctl version
istioctl proxy-status
```

```text
client version: 1.30.5
control plane version: 1.30.5
data plane version: 1.30.5 (2 proxies)
```

Two proxies: the workload's sidecar and the gateway. `istioctl` is read-only here — running `version` or `proxy-status` against a Helm-managed cluster does not make `istioctl` an owner of the install. Only `istioctl install` and `istioctl uninstall` would.

---

## Step 8: Submit

```sh
astrona submit
```

The grader reads Helm's own release Secrets to confirm all three releases exist and report `deployed`, checks the `istiod` image is `1.30.5`, checks `accessLogFile` in the live mesh ConfigMap and the absence of an `istiod` HPA, confirms `public-gateway` is running in `edge` with an `istio-proxy` container, confirms no egress gateway exists anywhere, and confirms `mesh-demo`'s single Deployment was restarted into the mesh with a matching proxy version.

---

## Common Mistakes

*   **Installing `istiod` before `istio-base`.** It fails with `resource mapping not found` naming a missing kind. That is the API server, not a broken chart — the CRDs are not there yet. Read the kind in the error.
*   **Using `istioctl install` because it is fewer commands.** There will be no Helm release Secrets, so the grader reports no release found. It is also the thing the module explicitly warns against: two owners of the same objects overwrite each other.
*   **Getting the gateway release name wrong.** `helm install istio-ingressgateway istio/gateway -n edge` produces `deployment/istio-ingressgateway`, not `public-gateway`. The release name *is* the object name.
*   **Installing the gateway into `istio-system`.** The task names `edge`, and mixing an internet-facing workload into the control plane namespace is the habit the module argues against.
*   **Passing `accessLogFile` with `--set` only.** It will pass the ConfigMap check, but the task asks for a values file — and the reason is real: section 030's upgrade module shows what happens when a release's configuration exists nowhere but in the release.
*   **Omitting `--version`.** The install works today and is unpinned; two runs a month apart give two different Istio versions, and the grader checks for `1.30.5` specifically.
*   **Forgetting the rollout restart.** Same trap as Module 1. The namespace label changes nothing for a pod that already exists.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [istioctl installation](https://istio.io/v1.30/docs/setup/install/istioctl/) — `istioctl install`, `--set`, and what the command actually applies
- [Install with Helm](https://istio.io/v1.30/docs/setup/install/helm/) — the charts, their values, and install ordering
- [Configuration profiles](https://istio.io/v1.30/docs/setup/additional-setup/config-profiles/) — what each built-in profile turns on
- [Canary upgrades](https://istio.io/v1.30/docs/setup/upgrade/canary/) — revisions, revision labels and moving workloads between control planes
- [Sidecar injection](https://istio.io/v1.30/docs/setup/additional-setup/sidecar-injection/) — the namespace label, the pod annotation, and when injection happens
- [ztunnel architecture](https://istio.io/v1.30/docs/ambient/architecture/data-plane/) — the node proxy and what it does and does not do
- [Istio CNI plugin](https://istio.io/v1.30/docs/setup/additional-setup/cni/) — replacing the init container's iptables work
- [Global mesh options](https://istio.io/v1.30/docs/reference/config/istio.mesh.v1alpha1/) — every mesh-wide setting and its default
- [Istio annotations and labels](https://istio.io/v1.30/docs/reference/config/annotations/) — the reference list of both
- [Diagnostic tools](https://istio.io/v1.30/docs/ops/diagnostic-tools/proxy-cmd/) — `proxy-status` and `proxy-config` in full
- [istioctl command reference](https://istio.io/v1.30/docs/reference/commands/istioctl/) — every subcommand and flag
- [Uninstalling Istio](https://istio.io/v1.30/docs/setup/install/istioctl/#uninstall-istio) — removing a control plane or one revision cleanly
- [Installing gateways](https://istio.io/v1.30/docs/setup/additional-setup/gateway/) — deploying gateways separately from the control plane
