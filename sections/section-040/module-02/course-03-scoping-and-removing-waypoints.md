# Scoping And Removing Waypoints

A namespace waypoint sends every request in the namespace through an extra proxy, even requests that only need layer 4. That costs delay and resources, and the cost grows with each namespace you enroll. This part shows how to give a waypoint to a single Service instead of a whole namespace, and what exactly is lost, and what is kept, when a waypoint is deleted.

The commands below need the `ambient-l7` namespace with a namespace waypoint named `waypoint`, created with `istioctl waypoint apply -n ambient-l7 --enroll-namespace`, and the `notification-header` `HTTPRoute`, which sets the response header `x-processed-by: waypoint`. If your playground is fresh, create both first.

## Namespace waypoints and service waypoints

A waypoint can serve a whole namespace or only chosen Services. This section shows both, and which one ztunnel picks when both apply to the same Service.

### Two ways to scope a waypoint

`istioctl waypoint apply --enroll-namespace` gives the whole namespace one waypoint. That is the usual starting point: one proxy, one place to attach policy, and every Service in the namespace gains layer 7 features.

The other option is a **service waypoint**. You create it with `--for service`, and attach it to chosen Services by adding the label `istio.io/use-waypoint` to each Service. The label names the waypoint that ztunnel, the per-node proxy of ambient mode, must send that Service's traffic through. Two situations call for a service waypoint:

- **One Service needs layer 7 and the others do not.** A namespace waypoint sends *all* the namespace's traffic through the extra hop, including traffic that only needs layer 4. A service waypoint avoids that delay for the other Services.
- **One Service needs its own capacity.** A busy Service can have its own proxy, scaled and sized apart from everything else.

Both kinds are `Gateway` objects of class `istio-waypoint`. The difference is entirely in **which label points at them**, a namespace label or a Service label, not in the object itself.

### A service waypoint in practice

Create a second waypoint named `svc-waypoint`, wait for its Deployment, and add the label to the `notification-service` Service so it points at the new waypoint:

<!-- astrona:playground:renew -->

```sh
istioctl waypoint apply -n ambient-l7 --name svc-waypoint --for service
kubectl -n ambient-l7 rollout status deployment svc-waypoint --timeout=180s
kubectl -n ambient-l7 label service notification-service istio.io/use-waypoint=svc-waypoint
istioctl waypoint list -n ambient-l7
```

The waypoint list looks like this:

```text
NAME           REVISION   PROGRAMMED
svc-waypoint   default    True
waypoint       default    True
```

Two waypoints are running. Now check which one ztunnel uses for the Service:

```sh
istioctl ztunnel-config service | grep ambient-l7
```

In this service view, the `WAYPOINT` column on the `notification-service` row now names `svc-waypoint`, because of the Service label. The label on the Service beats the label on the namespace: the narrower scope wins, the same rule Istio follows for its other labels.

Undo the change before you go on. The trailing `-` in `istio.io/use-waypoint-` removes the label:

```sh
kubectl -n ambient-l7 label service notification-service istio.io/use-waypoint-
istioctl waypoint delete svc-waypoint -n ambient-l7
```

## What you lose when the waypoint goes away

Scoping decides which Services pay for the waypoint. The other question is what happens when a waypoint disappears, by mistake or on purpose. Deleting a waypoint removes the layer 7 hop and nothing else. ztunnel keeps doing its job, so the mesh does not break; it only loses its layer 7 features.

The table shows which features belong to the waypoint and which belong to ztunnel:

| Lost | Kept |
| --- | --- |
| HTTP (Hypertext Transfer Protocol) routing and traffic splitting | Mutual TLS (Transport Layer Security) between workloads |
| Header changes | Workload identity (SPIFFE) |
| Retries, timeouts, circuit breaking | Layer 4 `AuthorizationPolicy` (identity, port) |
| `AuthorizationPolicy` rules that match an HTTP method, path or header | Connection-level telemetry |
| Request-level telemetry | Traffic keeps flowing |

SPIFFE (Secure Production Identity Framework For Everyone) is the identity format Istio gives each workload, based on its service account. So a deleted waypoint **reduces the mesh to layer 4 instead of breaking it**. Traffic keeps flowing, encrypted and checked, while the layer 7 rules you relied on stop applying without any error.

That is a security risk. An `AuthorizationPolicy` is the Istio object that allows or denies requests to a workload. Say one was the only thing that enforced an HTTP-level rule, such as denying `POST` to an admin path. Remove the waypoint, and that rule is no longer enforced. The policy object stays in the cluster and looks healthy, `kubectl get authorizationpolicy` still lists it, and nothing alerts you.

Delete the waypoint, send a request, then check ztunnel's workload view and count the recent lines in the ztunnel log that carry a source identity:

```sh
istioctl waypoint delete waypoint -n ambient-l7
kubectl -n ambient-l7 exec deploy/tester -- curl -s -i http://notification-service/ | head -3
istioctl ztunnel-config workload | grep ambient-l7 | head -3
kubectl -n istio-system logs ds/ztunnel --tail=10 | grep -c 'src.identity'
```

The output looks like this (shortened):

```text
HTTP/1.1 200 OK
Server: nginx/1.27.4
Date: Sat, 27 Sep 2026 09:56:40 GMT

NAMESPACE   POD NAME                      ADDRESS      NODE                     WAYPOINT  PROTOCOL
ambient-l7  notification-service-v1-...   10.244.0.14  astro-...-control-plane  None      HBONE

3
```

`Server: nginx` and no `x-processed-by` header show that the layer 7 processing is gone. `PROTOCOL HBONE`, and source identities still in ztunnel's log, show that mutual TLS and identity are untouched. The mesh did not break; it lost its layer 7 features. To keep exploring, create the waypoint again with `istioctl waypoint apply -n ambient-l7 --enroll-namespace`.

## Running waypoints in production

The playground shows the mechanics. A few more facts matter when you run waypoints on a real cluster, and each one follows from the waypoint being an extra hop that you own.

**The Gateway API is the documented way to configure layer 7 in ambient mode.** `VirtualService` is still the right tool for sidecar-mode meshes, and Istio still accepts it for waypoints. New ambient work should use `HTTPRoute` and the rest of the Gateway API.

**A waypoint is a Deployment you own.** It needs resource requests, a replica count that matches the traffic through it, and a `PodDisruptionBudget` if it sits on a critical path. `istioctl waypoint apply` gives you a working default, not production sizing.

**Match each policy to the component that enforces it.** Layer 4 rules work everywhere in an ambient mesh, because ztunnel enforces them. Layer 7 rules need a waypoint in the path for every workload they should cover. A namespace where only some Services have a waypoint has partial enforcement, which is worse than none, because it looks complete.

**`istioctl waypoint status` is the first check when layer 7 stops working.** A waypoint whose `Gateway` is not `Programmed`, or whose pod is not running, gives the same symptom as no waypoint at all: traffic flows, and the layer 7 rules do nothing.

You now know how to scope a waypoint to one Service with `--for service` and the `istio.io/use-waypoint` label, that the Service label beats the namespace label, and that deleting a waypoint reduces the mesh to layer 4 without an error. The open question for every ambient namespace is which Services really need layer 7, so that only they pay for the extra hop.

## Common pitfalls

> [!WARNING]
> **Giving every namespace a waypoint by default.** Each one is an extra hop with its own running costs. Use a service waypoint when only one Service needs layer 7.
>
> **Forgetting that the Service label wins.** A Service labelled `istio.io/use-waypoint` uses that waypoint, even when its namespace points at another one.
>
> **Assuming deleting a waypoint is safe because traffic still flows.** It is safe at layer 4. Any layer 7 authorization rule stops being enforced, and no error appears.
>
> **Mixing `VirtualService` and `HTTPRoute` for the same Service.** Istio still accepts `VirtualService` for waypoints, but using both gives behaviour nobody can predict from reading either one.
>
> **Treating the `istioctl waypoint apply` default as production sizing.** A waypoint needs its own resource requests and replica count.

## Your mission: Scope A Waypoint To One Service

You can now scope a waypoint to one Service and tell which waypoint, if any, ztunnel uses for each Service. The lab asks you to replace a namespace-wide waypoint with a service waypoint, so that only `notification-service` goes through layer 7 and `reporting-service` stays on layer 4.

The lab runs on its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-013-playground-040-02
```

Then start the lab. The task is on the next page; solve it on your own first:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-040/module-02/labs/lab-02
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/module-02/labs/lab-02
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-013-lab-040-02-02
astrona start ats-013-playground-040-02
```
