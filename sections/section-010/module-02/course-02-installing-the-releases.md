# Part 2 — Installing The Three Releases

> Prerequisite: [Part 1 — The Chart Model And Its Ordering](./course-01-chart-model-and-ordering.md). Next: [Part 3 — Release State, Verification And Cleanup](./course-03-release-state-and-verification.md).

Part 1 settled what the charts are and why they go in that order. This part runs them, and takes apart the two flags and one values file that carry all the actual decisions. By the end you have a working control plane and an ingress gateway, installed the way a pipeline would install them.

## Namespaces first

Neither `base` nor `istiod` creates `istio-system`, and the gateway chart does not create its namespace either. Helm's `--create-namespace` works, but creating them explicitly is worth the extra line: it is where labels, quotas and network policies go, and having them exist before the install makes those a normal part of the manifest rather than an afterthought.

```sh
kubectl create namespace istio-system
kubectl create namespace istio-ingress
```

## `base`: definitions, and nothing running

```sh
helm install istio-base istio/base -n istio-system \
  --version 1.30.5 --set defaultRevision=default --wait
```

Three things in that line deserve a sentence each.

**`--version 1.30.5`** pins the chart. Without it, Helm installs whatever is newest in the repo at the moment you run it, so the same command two months apart gives two different Istio versions. On a production install this is not optional, and it is what makes the upgrade in section 030 a deliberate act rather than a side effect of a `helm repo update`.

**`--wait`** makes Helm block until the release's resources report ready, rather than returning as soon as the API server accepts them. For `base` there are no pods to wait for, so it is nearly instant — but including it uniformly on all three installs is what stops a script racing ahead to `istiod` before the CRDs are actually established.

**`--set defaultRevision=default`** tells the chart which control-plane revision owns the *unrevisioned* injection webhook. Section 030 covers revisions properly; the short version is that a namespace labelled `istio-injection=enabled` needs some revision to claim it, and this is where you say which. Omit it on a single-control-plane install and injection can silently fail later with no webhook willing to serve the namespace — a failure that looks nothing like its cause.

> [!TIP]
> **Try it — a chart that installs no pods**
>
> ```sh
> helm install istio-base istio/base -n istio-system --version 1.30.5 --set defaultRevision=default --wait
> helm ls -n istio-system
> kubectl get crd | grep -c istio.io
> kubectl -n istio-system get pods
> ```
>
> Expect something like:
>
> ```text
> NAME            NAMESPACE       REVISION    STATUS      CHART           APP VERSION
> istio-base      istio-system    1           deployed    base-1.30.5     1.30.5
>
> 15
> No resources found in istio-system namespace.
> ```
>
> A deployed release, a double-digit pile of CRDs, and zero pods. `base` is pure definitions — which is precisely why installing `istiod` first fails: the kinds it needs would not exist yet.

## `istiod`: where configuration enters

Write the values file before running anything, so the configuration is a committed artifact rather than a shell flag:

```sh
cat > istiod-values.yaml <<'YAML'
meshConfig:
  accessLogFile: /dev/stdout
  outboundTrafficPolicy:
    mode: ALLOW_ANY
pilot:
  autoscaleEnabled: false
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
global:
  proxy:
    resources:
      requests:
        cpu: 10m
        memory: 64Mi
YAML
```

Three top-level keys, three different audiences and three different places the result shows up:

- **`meshConfig`** is mesh-wide runtime behaviour — access logging, outbound traffic policy, tracing. It is rendered verbatim into a ConfigMap named `istio` in `istio-system`, under a key called `mesh`. `istiod` reads that ConfigMap and distributes the relevant parts to every proxy.
- **`pilot`** configures the control plane workload itself: replicas, autoscaling, resource requests, affinity. `pilot` is the historical name of the component that became `istiod`, which is why the key looks unfamiliar — it is the `istiod` Deployment.
- **`global.proxy`** sets defaults applied to *every injected sidecar*. This is the one whose cost multiplies: a 10m CPU request here is 10m per meshed pod, not 10m total.

Mapping those onto the `IstioOperator` tree from Module 1: `meshConfig` is `spec.meshConfig`, `pilot` is roughly `spec.components.pilot.k8s`, and `global.proxy` is `spec.values.global.proxy`. The Helm values file *is* the `spec.values` subtree, which is why the two install methods read the same documentation.

Then install:

```sh
helm install istiod istio/istiod -n istio-system \
  --version 1.30.5 -f istiod-values.yaml --wait
```

> [!TIP]
> **Try it — confirm the values reached the cluster, not just the release**
>
> ```sh
> kubectl -n istio-system get deploy istiod
> kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | head -12
> kubectl -n istio-system get deploy istiod -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}{"\n"}'
> ```
>
> Expect something like:
>
> ```text
> NAME     READY   UP-TO-DATE   AVAILABLE   AGE
> istiod   1/1     1            1           48s
>
> accessLogFile: /dev/stdout
> defaultConfig:
>   discoveryAddress: istiod.istio-system.svc:15012
>   proxyMetadata: {}
> ...
> outboundTrafficPolicy:
>   mode: ALLOW_ANY
>
> 100m
> ```
>
> The `mesh` key in the `istio` ConfigMap is the live `meshConfig` — not what you typed, but what the cluster is running. When a mesh-wide setting "isn't working", this answers the first question unambiguously: did it ever arrive? The `100m` proves the `pilot` block landed on the Deployment.

Note what the two checks do *not* prove: that proxies have received the setting. The ConfigMap is the control plane's input; `istioctl proxy-status` is how you check the push reached the data plane. Keeping those two questions separate is the difference between a five-minute diagnosis and an afternoon.

## `gateway`: a release per edge

```sh
helm install istio-ingressgateway istio/gateway -n istio-ingress \
  --version 1.30.5 --wait
```

No values file here, because the defaults are reasonable and everything interesting about a gateway — which ports, which hosts, which TLS certificates — is configured at *runtime* through a `Gateway` resource, not at install time. The chart's job is to put an Envoy and a Service in the namespace; what that Envoy serves is a separate, non-install-time decision.

> [!TIP]
> **Try it — the gateway and where it lives**
>
> ```sh
> kubectl -n istio-ingress get deploy,svc
> kubectl -n istio-ingress get pod -l app=istio-ingressgateway \
>   -o jsonpath='{.items[0].spec.containers[*].name}{"\n"}'
> ```
>
> Expect something like:
>
> ```text
> NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
> deployment.apps/istio-ingressgateway   1/1     1            1           35s
>
> NAME                           TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
> service/istio-ingressgateway   LoadBalancer   10.96.148.22   <pending>     15021:31...,80:31...,443:31...
>
> istio-proxy
> ```
>
> One container called `istio-proxy` — the same Envoy image a sidecar runs, deployed standalone. `EXTERNAL-IP <pending>` is expected on kind, which has no cloud load balancer; the Service still works through its node ports.

## Which settings belong at install time

A recurring question once you have a values file: does this setting go in the chart values or in a runtime resource? The boundary is the same one Module 1 drew for `istioctl`:

| Install-time (values file) | Runtime (Kubernetes resources) |
| --- | --- |
| Which components exist, and how many replicas | Which hosts a gateway serves (`Gateway`) |
| Control plane sizing and autoscaling | Routing and traffic splitting (`VirtualService`) |
| Mesh-wide defaults (`meshConfig`) | Per-workload logging and tracing (`Telemetry`) |
| Default sidecar resources | mTLS mode and authorization (`PeerAuthentication`, `AuthorizationPolicy`) |

Getting a setting on the wrong side of that line is not a syntax error — it is a `helm upgrade` for something that should have been a `kubectl apply`, with a control plane restart you did not need.

> *The values file is the `spec.values` tree under another name; `meshConfig` lands in a ConfigMap, `pilot` lands on the Deployment, and `global.proxy` multiplies by every meshed pod.*

## Common pitfalls

> [!WARNING]
> **Omitting `--version`.** Helm installs whatever the repository currently offers, so two runs a month apart install two different Istio versions.
>
> **Creating the namespace as an afterthought.** `helm install -n` does not create it unless you ask; `--create-namespace` or a prior `kubectl create ns` is part of the step.
>
> **Setting a mesh-wide value on the wrong release.** `meshConfig` belongs to `istiod`. Passing it to `base` or `gateway` is accepted by Helm and does nothing.
>
> **Leaving `defaultRevision` unset when you meant to own the default.** The injection webhook needs a revision to point at, and section 030 depends on this being deliberate.
>
> **Configuring at install time what belongs in a runtime object.** Gateways, routing and policy are Istio objects you apply later, not chart values.

## Reference

- [Install with Helm](https://istio.io/v1.30/docs/setup/install/helm/) — the procedure this part follows.
- [Global mesh options](https://istio.io/v1.30/docs/reference/config/istio.mesh.v1alpha1/) — every `meshConfig` field and its default.
- [istiod chart values](https://artifacthub.io/packages/helm/istio-official/istiod) — the full value schema for the version you are installing.
- `helm show values istio/istiod` — the same schema, from the chart you actually have.
