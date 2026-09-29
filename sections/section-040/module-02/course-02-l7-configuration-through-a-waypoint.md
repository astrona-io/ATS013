# Part 2 — L7 Configuration Through A Waypoint

> Prerequisite: [Part 1 — What A Waypoint Is And How Traffic Reaches It](./course-01-what-a-waypoint-is.md). Next: [the module landing page](./course.md).

Part 1 ended with a waypoint running and ztunnel routing through it. The `HTTPRoute` from the start of that part is still applied and completely unchanged — it was correct all along and had no executor. This part watches it come alive, covers how to scope waypoints to something narrower than a whole namespace, and is precise about what degrades when a waypoint goes away.

## The same route, now that something can execute it

> [!TIP]
> **Try it — the same request, through L7**
>
> ```sh
> kubectl -n ambient-l7 exec deploy/tester -- curl -s -i http://notification-service/ | head -7
> ```
>
> Expect something like:
>
> ```text
> HTTP/1.1 200 OK
> server: istio-envoy
> date: Sat, 27 Sep 2026 09:48:11 GMT
> content-type: text/html
> content-length: 615
> x-envoy-upstream-service-time: 2
> x-processed-by: waypoint
> ```
>
> Two proofs on one screen. `x-processed-by: waypoint` is a header no application set — an HTTP-aware proxy added it. And `server: istio-envoy` rather than `nginx/1.27.4` shows the response passed through Envoy on its way back, which it did not in Part 1's identical request. `x-envoy-upstream-service-time` is a third tell: Envoy timing the upstream call.
>
> Nothing about the `HTTPRoute` changed between the two runs. The only difference is that something now exists to execute it.

That contrast is worth holding onto as a diagnostic habit. When L7 configuration in an ambient namespace appears to do nothing, the first question is not "is my route correct?" but "is there a waypoint, and is this workload routed through it?" — `istioctl ztunnel-config workload` answers the second in one line.

## Reading the route's status honestly

The `HTTPRoute` reported `Accepted` and `ResolvedRefs` in Part 1, before the waypoint existed, and reports the same now. That is not a bug in the status; it is the status answering a narrower question than people assume.

| Condition | Means | Does **not** mean |
| --- | --- | --- |
| `Accepted` | The route is well-formed and bound to the parent named in `parentRefs` | Anything is executing it |
| `ResolvedRefs` | Every `backendRefs` target exists and is reachable as a reference | Traffic is reaching that backend |

So route status is a validation signal, not a functional one. The functional check is the response — a header, a status code, a timing header — or `istioctl proxy-config route` against the waypoint pod, which shows the routes Envoy actually received.

> [!TIP]
> **Try it — see the route inside the waypoint's Envoy**
>
> ```sh
> WP=$(kubectl -n ambient-l7 get pod -l gateway.networking.k8s.io/gateway-name=waypoint -o jsonpath='{.items[0].metadata.name}')
> istioctl proxy-config route "$WP.ambient-l7" | head -10
> ```
>
> Expect something like:
>
> ```text
> NAME                                          VHOST NAME                              DOMAINS     MATCH     VIRTUAL SERVICE
> inbound-vip|80|http|notification-service...   inbound|http|80                         *           /*        notification-header.ambient-l7
> ```
>
> The waypoint is an ordinary Envoy, so the ordinary `istioctl proxy-config` commands work against it — the same tooling you would use on a sidecar. Seeing your route's name in the `VIRTUAL SERVICE` column is the strongest available evidence that the configuration reached the proxy, as opposed to merely existing in the cluster.

## Namespace waypoints and service waypoints

`istioctl waypoint apply --enroll-namespace` gives the whole namespace one waypoint. That is the common starting point: one proxy, one place to attach policy, and every service in the namespace gains L7 capability.

The alternative is a **service waypoint**, created with `--for service` and attached to specific Services by labelling them `istio.io/use-waypoint`. Two situations call for it:

- **One service needs L7 and the rest do not.** A namespace waypoint routes *all* the namespace's traffic through the extra hop, including traffic that only ever needed L4. Scoping avoids paying latency for nothing.
- **One service needs its own capacity.** A high-throughput service can have a dedicated proxy, scaled and sized independently of everything else.

Both are `Gateway` resources of class `istio-waypoint`. The difference is entirely in **who is pointed at them** — a namespace label versus Service labels — not in the object.

> [!TIP]
> **Try it — scope a waypoint to one Service**
>
> ```sh
> istioctl waypoint apply -n ambient-l7 --name svc-waypoint --for service
> kubectl -n ambient-l7 rollout status deployment svc-waypoint --timeout=180s
> kubectl -n ambient-l7 label service notification-service istio.io/use-waypoint=svc-waypoint
> istioctl waypoint list -n ambient-l7
> istioctl ztunnel-config workload | grep ambient-l7
> ```
>
> Expect something like:
>
> ```text
> NAME           REVISION   PROGRAMMED
> svc-waypoint   default    True
> waypoint       default    True
>
> NAMESPACE   POD NAME                      ADDRESS      NODE                     WAYPOINT      PROTOCOL
> ambient-l7  notification-service-v1-...   10.244.0.14  astro-...-control-plane  svc-waypoint  HBONE
> ambient-l7  tester-...                    10.244.0.15  astro-...-control-plane  waypoint      HBONE
> ```
>
> Two waypoints running, and the `WAYPOINT` column now differs per workload: traffic to `notification-service` goes through `svc-waypoint` because of the Service label, while the rest of the namespace still uses the namespace waypoint. The Service-level label wins over the namespace-level one — more specific scope, higher precedence, the same pattern as every other label in this course.
>
> Remove it again with `kubectl -n ambient-l7 label service notification-service istio.io/use-waypoint-` and `istioctl waypoint delete svc-waypoint -n ambient-l7` before moving on.

## What you lose if the waypoint goes away

Deleting a waypoint removes the L7 hop and nothing else:

| Lost | Kept |
| --- | --- |
| HTTP routing and traffic splitting | Mutual TLS between workloads |
| Header manipulation | Workload identity (SPIFFE) |
| Retries, timeouts, circuit breaking | L4 `AuthorizationPolicy` (identity, port) |
| `AuthorizationPolicy` rules matching HTTP method / path / header | Connection-level telemetry |
| Request-level telemetry | Traffic keeps flowing |

So a deleted waypoint **degrades the mesh to L4 rather than breaking it**. Traffic keeps flowing, encrypted and authenticated, while the L7 rules you relied on stop applying — quietly, in exactly the way they never applied before the waypoint existed.

The security consequence deserves stating plainly: if an `AuthorizationPolicy` was the only thing enforcing an HTTP-level restriction — say, denying `POST` to an admin path — removing the waypoint removes the restriction, while the policy object remains in the cluster looking perfectly healthy. Nothing alerts, and a `kubectl get authorizationpolicy` shows it present.

> [!TIP]
> **Try it — watch L7 degrade while L4 survives**
>
> ```sh
> istioctl waypoint delete waypoint -n ambient-l7
> kubectl -n ambient-l7 exec deploy/tester -- curl -s -i http://notification-service/ | head -3
> istioctl ztunnel-config workload | grep ambient-l7 | head -3
> kubectl -n istio-system logs ds/ztunnel --tail=10 | grep -c 'src.identity'
> ```
>
> Expect something like:
>
> ```text
> HTTP/1.1 200 OK
> Server: nginx/1.27.4
> Date: Sat, 27 Sep 2026 09:56:40 GMT
>
> NAMESPACE   POD NAME                      ADDRESS      NODE                     WAYPOINT  PROTOCOL
> ambient-l7  notification-service-v1-...   10.244.0.14  astro-...-control-plane  None      HBONE
>
> 3
> ```
>
> `Server: nginx` and no `x-processed-by` — the L7 processing is gone. `PROTOCOL HBONE` and identities still in ztunnel's logs — the mTLS and the identity are untouched. That is the degradation, made visible in one screen: the mesh did not break, it got smaller.
>
> Recreate it with `istioctl waypoint apply -n ambient-l7 --enroll-namespace` if you want to keep exploring.

> [!WARNING]
## Common pitfalls

> [!WARNING]
> **An `HTTPRoute` in a namespace with no waypoint.** Accepted, statused, and completely inert. Check `istioctl ztunnel-config workload` for a non-`None` `WAYPOINT` before debugging the route.
>
> **Missing Gateway API CRDs.** `istioctl waypoint apply` fails with an unknown-kind error that looks like an Istio problem. Install the CRDs separately.
>
> **Creating a waypoint without enrolling anything.** Without `--enroll-namespace` or a Service label, the proxy runs and receives no traffic.
>
> **Reading route status as proof of effect.** `Accepted` means well-formed and bound, not enforced.
>
> **Expecting a waypoint to cover traffic that is not in the mesh.** Both ends still need to be meshed for ztunnel to capture the connection. A client outside the mesh reaches the Service directly, bypassing the waypoint entirely.
>
> **Assuming deleting a waypoint is safe because traffic still flows.** It is, at L4. Any L7 authorization rule silently stops being enforced.
>
> **Mixing `VirtualService` and `HTTPRoute` for the same Service.** Istio still accepts `VirtualService` for waypoints, but using both produces behaviour nobody can predict from reading either one.

## Operational considerations

**Gateway API is the documented path for ambient L7.** `VirtualService` remains the right tool for sidecar-mode meshes and is still accepted here, but new ambient work should use `HTTPRoute` and the rest of the Gateway API.

**A waypoint is a Deployment you own.** It needs resource requests, a replica count matched to the traffic through it, and a `PodDisruptionBudget` if it is on a critical path. `istioctl waypoint apply` gives you a working default, not a production sizing.

**It is an extra hop, so it costs latency.** That is the argument for scoping waypoints narrowly — per service where only one service needs L7 — rather than defaulting every namespace to one.

**Scope policy to the layer that enforces it.** L4 rules work everywhere in an ambient mesh. L7 rules need a waypoint in the path for every workload they are meant to cover, so a namespace with a partial waypoint rollout has partial enforcement — which is worse than none, because it looks complete.

**`istioctl waypoint status` is the first check when L7 stops working.** A waypoint whose `Gateway` is not `Programmed`, or whose pod is not running, produces exactly the same symptom as no waypoint at all: traffic flows and the L7 rules do nothing.

> *A waypoint's absence is indistinguishable from its silence — traffic keeps flowing at L4, so check for the waypoint before you debug the route.*

## Reference

- [Waypoint proxies](https://istio.io/v1.30/docs/ambient/usage/waypoint/) — namespace and service scoping, and the `istio.io/use-waypoint` label.
- [L7 features in ambient mode](https://istio.io/v1.30/docs/ambient/usage/l7-features/) — what a waypoint adds over ztunnel.
- [HTTPRoute](https://gateway-api.sigs.k8s.io/api-types/httproute/) — filters, matches and backend references.
- [Diagnostic tools](https://istio.io/v1.30/docs/ops/diagnostic-tools/proxy-cmd/) — `proxy-config` against a waypoint pod.
