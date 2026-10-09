# Scoping And Removing Waypoints

A waypoint is a checkpoint station, and every station costs something to run. In this part you learn to build one for a single Service instead of a whole planet (namespace), and you see exactly what is lost, and what is kept, when a waypoint goes away.

The commands below assume your playground's `ambient-l7` namespace has a namespace waypoint named `waypoint`, created with `istioctl waypoint apply -n ambient-l7 --enroll-namespace`, and the `notification-header` `HTTPRoute`, which sets the response header `x-processed-by: waypoint`. If you started a fresh playground, run that `istioctl waypoint apply` command first.

## Namespace waypoints and service waypoints

`istioctl waypoint apply --enroll-namespace` gives the whole namespace one waypoint. That is the usual starting point: one proxy, one place to attach policy, and every Service in the namespace gains layer 7 abilities.

### When a service waypoint is the better choice

The other option is a **service waypoint**. You create it with `--for service`, and attach it to chosen Services by labelling them `istio.io/use-waypoint`. That label tells a beacon (Service) to route its signals through a particular checkpoint station. Two situations call for it:

- **One Service needs layer 7 and the others do not.** A namespace waypoint sends *all* the namespace's traffic through the extra hop, including traffic that only needed layer 4. Scoping it avoids paying that delay for nothing.
- **One Service needs its own capacity.** A busy Service can have its own proxy, scaled and sized apart from everything else.

Both kinds are `Gateway` objects of class `istio-waypoint`. The difference is entirely in **who points at them**, a namespace label or Service labels, not in the object itself.

<!-- astrona:playground:renew -->

### See it in your playground

Create a second waypoint for one Service, wait for it, and point `notification-service` at it:

```sh
istioctl waypoint apply -n ambient-l7 --name svc-waypoint --for service
kubectl -n ambient-l7 rollout status deployment svc-waypoint --timeout=180s
kubectl -n ambient-l7 label service notification-service istio.io/use-waypoint=svc-waypoint
istioctl waypoint list -n ambient-l7
```

The waypoint list looks something like this:

```text
NAME           REVISION   PROGRAMMED
svc-waypoint   default    True
waypoint       default    True
```

Two waypoints are running. Now check which one ztunnel uses for the Service:

```sh
istioctl ztunnel-config service | grep ambient-l7
```

In this service view, the `WAYPOINT` column on the `notification-service` row now names `svc-waypoint`, because of the Service label. The label on the Service beats the label on the namespace: the narrower scope wins, the same pattern as every other Istio label.

Undo it before you go on:

```sh
kubectl -n ambient-l7 label service notification-service istio.io/use-waypoint-
istioctl waypoint delete svc-waypoint -n ambient-l7
```

## What you lose if the waypoint goes away

Deleting a waypoint removes the layer 7 hop and nothing else. The relay towers (ztunnel) keep doing their job, so the mesh does not break; it gets smaller.

### Lost and kept

The table shows which abilities belong to the waypoint and which belong to ztunnel:

| Lost | Kept |
| --- | --- |
| HTTP routing and traffic splitting | Mutual TLS between workloads |
| Header changes | Workload identity (SPIFFE) |
| Retries, timeouts, circuit breaking | Layer 4 `AuthorizationPolicy` (identity, port) |
| `AuthorizationPolicy` rules matching HTTP method, path or header | Connection-level telemetry |
| Request-level telemetry | Traffic keeps flowing |

So a deleted waypoint **drops the mesh to layer 4 instead of breaking it**. Traffic keeps flowing, encrypted and checked, while the layer 7 rules you relied on quietly stop applying.

### The security risk

Say an `AuthorizationPolicy`, the guard's list at the airlock, was the only thing enforcing an HTTP-level rule, such as denying `POST` to an admin path. Remove the waypoint, and the rule is gone. The policy object stays in the cluster and looks perfectly healthy. Nothing alerts you, and `kubectl get authorizationpolicy` still shows it.

### See it in your playground

Delete the waypoint, send a request, and check ztunnel and its log:

```sh
istioctl waypoint delete waypoint -n ambient-l7
kubectl -n ambient-l7 exec deploy/tester -- curl -s -i http://notification-service/ | head -3
istioctl ztunnel-config workload | grep ambient-l7 | head -3
kubectl -n istio-system logs ds/ztunnel --tail=10 | grep -c 'src.identity'
```

Expect something like:

```text
HTTP/1.1 200 OK
Server: nginx/1.27.4
Date: Sat, 27 Sep 2026 09:56:40 GMT

NAMESPACE   POD NAME                      ADDRESS      NODE                     WAYPOINT  PROTOCOL
ambient-l7  notification-service-v1-...   10.244.0.14  astro-...-control-plane  None      HBONE

3
```

`Server: nginx` and no `x-processed-by` header: the layer 7 processing is gone. `PROTOCOL HBONE`, and identities still in ztunnel's log: mutual TLS and identity are untouched. That is the whole story on one screen. The mesh did not break, it got smaller.

Build it again with `istioctl waypoint apply -n ambient-l7 --enroll-namespace` if you want to keep exploring.

## Running waypoints for real

A few facts help when you run waypoints outside the playground. Each one follows from the waypoint being an extra hop that you own.

**The Gateway API is the documented way to do layer 7 in ambient mode.** `VirtualService` is still the right tool for sidecar-mode meshes, and Istio still accepts it for waypoints. New ambient work should use `HTTPRoute` and the rest of the Gateway API.

**A waypoint is a Deployment you own.** It needs resource requests, a replica count that matches the traffic through it, and a `PodDisruptionBudget` if it sits on a critical path. `istioctl waypoint apply` gives you a working default, not production sizing.

**It is an extra hop, so it adds delay.** That is the argument for scoping waypoints narrowly, per Service where only one Service needs layer 7, instead of giving every namespace one by default.

**Match each policy to the layer that enforces it.** Layer 4 rules work everywhere in an ambient mesh. Layer 7 rules need a waypoint in the path for every workload they should cover. A namespace with a half-finished waypoint rollout has partial enforcement, which is worse than none, because it looks complete.

**`istioctl waypoint status` is the first check when layer 7 stops working.** A waypoint whose `Gateway` is not `Programmed`, or whose pod is not running, gives exactly the same symptom as no waypoint at all: traffic flows, and the layer 7 rules do nothing.

In short: a missing waypoint looks exactly like a quiet one. Traffic keeps flowing at layer 4, so check for the waypoint before you debug the route.

## Common pitfalls

> [!WARNING]
> **Giving every namespace a waypoint by default.** Each one is an extra hop with its own running costs. Use a service waypoint when only one Service needs layer 7.
>
> **Forgetting that the Service label wins.** A Service labelled `istio.io/use-waypoint` uses that waypoint, even when its namespace points at another one.
>
> **Assuming deleting a waypoint is safe because traffic still flows.** It is safe at layer 4. Any layer 7 authorization rule silently stops being enforced.
>
> **Mixing `VirtualService` and `HTTPRoute` for the same Service.** Istio still accepts `VirtualService` for waypoints, but using both gives behaviour nobody can predict from reading either one.
>
> **Treating the `istioctl waypoint apply` default as production sizing.** A waypoint needs its own resource requests and replica count.
