# Part 2 — meshConfig: From File To ConfigMap To Proxy

> Prerequisite: [Part 1 — The Four Configuration Layers](./course-01-the-four-configuration-layers.md). Next: [Part 3 — Writing, Validating And Re-applying The Document](./course-03-writing-validating-reapplying.md).

Of the four layers, `meshConfig` is the one whose live value you can read back directly — and that single property makes it the fastest debugging tool in the module. This part follows one setting the whole way from your file to a proxy enforcing it, and names the check available at each stage. The result is a diagnostic order you can apply to any mesh-wide setting, not just the one used here.

## The path a setting travels

```text
  your IstioOperator file
        │  spec.meshConfig
        ▼
  istioctl install  ──renders──►  ConfigMap "istio" in istio-system
        │                          key: mesh   (the whole meshConfig, as YAML)
        ▼
  istiod reads the ConfigMap at startup, and watches it for changes
        │
        │  recomputes each proxy's configuration
        ▼
  xDS push to every connected proxy   ──►   Envoy applies it
                                             (LDS/CDS/RDS, per Part 3 of
                                              the section 010 istioctl module)
```

Four stages, and a different check at each one:

| Stage | Question | Check |
| --- | --- | --- |
| File | Did I write it correctly? | `istioctl validate -f`, `istioctl manifest generate -f` |
| ConfigMap | Did it reach the cluster? | `kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}'` |
| Control plane | Did `istiod` act on it? | `istioctl proxy-status` — are proxies `SYNCED` or `STALE`? |
| Proxy | Is it being enforced? | Real traffic, or `istioctl proxy-config` |

Most wasted debugging time comes from skipping to the last row. "The setting isn't working" is four different faults, and the ConfigMap check takes two seconds and eliminates half of them.

## The ConfigMap is the control plane's input

`istiod` does not read your `IstioOperator` file — Part 1 of the section 010 module established that the file never reaches the cluster. What reaches the cluster is a ConfigMap named `istio` in `istio-system`, whose `mesh` key holds the entire `meshConfig` block as YAML.

That has a useful consequence and a dangerous one. Useful: the ConfigMap is an unambiguous record of what the control plane was told, independent of anything on anyone's disk. Dangerous: it is an ordinary ConfigMap, so `kubectl edit` works on it, `istiod` picks the change up, and the next `istioctl install` silently reverts it. Editing it directly is a way to test a setting quickly and a terrible way to configure a cluster.

> [!TIP]
> **Try it — read the baseline, and note what is absent**
>
> ```sh
> kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}'
> ```
>
> Expect something like:
>
> ```text
> defaultConfig:
>   discoveryAddress: istiod.istio-system.svc:15012
>   proxyMetadata: {}
>   tracing:
>     zipkin:
>       address: zipkin.istio-system:9411
> defaultProviders:
>   metrics:
>   - prometheus
> enablePrometheusMerge: true
> rootNamespace: istio-system
> trustDomain: cluster.local
> ```
>
> There is no `accessLogFile` key and no `outboundTrafficPolicy` key. The stock `demo` profile does not set them, and absent means "the built-in default applies" — not "off". `defaultConfig` is worth noticing too: it is the sub-block that becomes each proxy's own settings, including `discoveryAddress`, which is how a sidecar knows where `istiod` is.

## Applying a mesh-wide change

Set two `meshConfig` keys and watch them appear. The second one changes how every meshed workload reaches the outside world, so read the warning before running it.

```sh
cat > istio-custom.yaml <<'YAML'
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: demo
  meshConfig:
    accessLogFile: /dev/stdout
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
YAML
```

> [!WARNING]
> **`REGISTRY_ONLY` is a deny-by-default rule for outbound traffic**
>
> `outboundTrafficPolicy.mode` has two values. `ALLOW_ANY`, the default, lets a meshed pod connect to any host whether or not Istio knows about it. `REGISTRY_ONLY` blocks every destination that is not in the mesh registry — not a Kubernetes Service, and not declared with a `ServiceEntry`.
>
> That is a useful security posture and it is also an outage if you enable it without inventorying your outbound dependencies first. On this playground it is safe and instructive. On a shared cluster, expect calls to external APIs, package mirrors and webhooks to start failing the moment it takes effect.

> [!TIP]
> **Try it — apply, then check the ConfigMap stage**
>
> ```sh
> istioctl install -f istio-custom.yaml -y
> kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep -A2 -E 'accessLogFile|outboundTrafficPolicy'
> istioctl proxy-status
> ```
>
> Expect something like:
>
> ```text
> accessLogFile: /dev/stdout
> outboundTrafficPolicy:
>   mode: REGISTRY_ONLY
>
> NAME                                   CLUSTER      CDS      LDS      EDS      RDS        ISTIOD
> istio-ingressgateway-...istio-system   Kubernetes   SYNCED   SYNCED   SYNCED   NOT SENT   istiod-...
> ```
>
> Both keys are now present in the ConfigMap — stage 2 confirmed. Every proxy showing `SYNCED` confirms stage 3: `istiod` recomputed and pushed, and the proxies acknowledged. A few seconds of `STALE` immediately after an install is normal; a persistent `STALE` means a proxy is not accepting what it is being sent.

## Confirming enforcement with real traffic

The ConfigMap proves the setting was stored. `proxy-status` proves it was pushed. Neither proves a proxy is *acting* on it — and for `REGISTRY_ONLY` the difference is directly observable, because an in-mesh pod loses access to hosts the mesh does not know about while in-cluster Services keep working.

> [!TIP]
> **Try it — watch outbound traffic get blocked**
>
> ```sh
> kubectl label namespace default istio-injection=enabled --overwrite
> kubectl run tester --image=curlimages/curl:8.11.1 --command -- sh -c 'sleep 3600'
> kubectl wait --for=condition=Ready pod/tester --timeout=120s
> kubectl exec tester -c tester -- curl -s -o /dev/null -w 'external: %{http_code}\n' http://example.com
> kubectl exec tester -c tester -- curl -s -o /dev/null -w 'in-cluster: %{http_code}\n' http://istiod.istio-system.svc:15014/ready
> ```
>
> Expect something like:
>
> ```text
> external: 502
> in-cluster: 200
> ```
>
> The external host is refused by the sidecar with `502`; the in-cluster Service answers normally. Nothing about the pod changed between the two calls — the proxy is applying a mesh-wide rule that arrived through the ConfigMap. This is also exactly what it looks like when `REGISTRY_ONLY` is enabled by accident, which is why it is worth seeing once on purpose.

Note the failure is a `502` from the proxy, not a connection timeout or a DNS error. That distinction is the useful diagnostic: a timeout suggests a network path problem, while an immediate `502` from a meshed pod to an external host suggests mesh policy. The access logs you just enabled make it explicit — `kubectl logs tester -c istio-proxy --tail=5` shows the rejected request with a response flag indicating no route was found.

## Why a setting can be in the ConfigMap and still not apply

Two mechanisms produce that state, and both are worth recognising:

**The proxy has not received the push.** `istiod` distributes `meshConfig`-derived settings on its normal xDS cycle. A proxy that is disconnected, restarting, or wedged will keep its previous configuration. `proxy-status` shows this as `STALE` or as a missing entry.

**A runtime resource overrides it.** `meshConfig` sets *defaults*. A `Telemetry` resource can change logging for one namespace, a `DestinationRule` can change TLS behaviour for one host, and a `ServiceEntry` can make a specific external host reachable even under `REGISTRY_ONLY`. In every case the more specific runtime object wins, by design — and the ConfigMap will still show your mesh-wide setting, unchanged and genuinely in effect everywhere else.

That second case is not a bug to fix; it is the layering working. But it does mean "the ConfigMap says X and this workload does Y" has a normal explanation, and the next place to look is the runtime resources scoped to that workload.

> *`meshConfig` reaches the cluster as a ConfigMap, reaches proxies as an xDS push, and can be overridden per-workload by a runtime resource — check those three stages in that order.*

## Reference

- [Global mesh options](https://istio.io/v1.30/docs/reference/config/istio.mesh.v1alpha1/) — every `meshConfig` field, including `defaultConfig`.
- [Outbound traffic policy](https://istio.io/v1.30/docs/tasks/traffic-management/egress/egress-control/) — `REGISTRY_ONLY` and the `ServiceEntry` that makes a host reachable again.
- [Envoy access logging](https://istio.io/v1.30/docs/tasks/observability/logs/access-log/) — the format of what `accessLogFile` produces, and the `Telemetry` resource that scopes it.
- [Diagnostic tools](https://istio.io/v1.30/docs/ops/diagnostic-tools/proxy-cmd/) — `proxy-config` for inspecting what a single proxy actually received.
