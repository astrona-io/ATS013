# Part 2 — Enrollment, Verification And The L4 Boundary

> Prerequisite: [Part 1 — The Ambient Data Plane](./course-01-the-ambient-data-plane.md). Next: [the module landing page](./course.md), then [Module 2 — Add A Waypoint Proxy For L7 In Ambient Mode](../module-02/course.md).

Part 1 left a running ambient data plane with nothing enrolled. This part joins a namespace to the mesh, shows why that costs nothing, replaces the container-counting habit with a check that actually works here, and then draws the line ztunnel cannot cross — which is the reason the next module exists.

## Enrollment is a label, and nothing restarts

A namespace joins the ambient mesh through the label `istio.io/dataplane-mode=ambient`. `istiod` tells the node's ztunnel about the namespace's workloads, `istio-cni-node` programs their redirection, and traffic starts flowing through the tunnel.

Contrast the two mechanisms directly, because the difference is the whole operational argument for ambient mode:

| | Sidecar mode | Ambient mode |
| --- | --- | --- |
| What changes | The **pod spec** — a container is added | **Node-level** redirection and ztunnel's state |
| When it is decided | At pod creation, by an admission webhook | Continuously, by the control plane |
| To apply it to running pods | Recreate every pod | Nothing |
| To undo it | Recreate every pod again | Nothing |

Sidecar injection is a *mutation of the pod spec*, so it can only happen when the pod is admitted. Ambient enrollment changes things that live *outside* the pod, so the pod does not need to know and does not change.

The observable proof is the pod's `AGE`: note it before enrolling, and watch it keep counting up afterwards.

> [!TIP]
> **Try it — join the mesh without a restart**
>
> ```sh
> kubectl -n ambient-demo get pods
> kubectl label namespace ambient-demo istio.io/dataplane-mode=ambient
> kubectl -n ambient-demo get pods
> ```
>
> Expect something like:
>
> ```text
> NAME                                       READY   STATUS    RESTARTS   AGE
> notification-service-v1-6c8f9d7b5c-t7wqx   1/1     Running   0          6m
> tester-5b7d9c4f88-k2vnm                    1/1     Running   0          6m
>
> namespace/ambient-demo labeled
>
> NAME                                       READY   STATUS    RESTARTS   AGE
> notification-service-v1-6c8f9d7b5c-t7wqx   1/1     Running   0          6m12s
> tester-5b7d9c4f88-k2vnm                    1/1     Running   0          6m12s
> ```
>
> Same pod names, `RESTARTS` still 0, `AGE` twelve seconds larger. These workloads now have mutual TLS between them and nothing was recreated to achieve it. `READY 1/1` — still one container, and it will stay that way.

## Checking membership when containers do not tell you

In sidecar mode, `kubectl get pod` answered "is this in the mesh?" — two containers meant yes. In ambient mode every meshed pod still has exactly one container, so that check is not merely unhelpful, it **actively misleads**. A colleague grepping for `istio-proxy` will conclude the mesh is broken and may go and "fix" it.

The right question is what ztunnel knows, and `istioctl ztunnel-config workload` is how you ask. Read the name as the ztunnel counterpart of `istioctl proxy-config`: it dumps a running proxy's view of the world.

The `PROTOCOL` column is the answer:

- **`HBONE`** — the workload is enrolled. Traffic to it goes through the mTLS tunnel Part 1 described.
- **`TCP`** — plain traffic. The workload is not enrolled, or is something the mesh does not manage.

The `WAYPOINT` column is the other half of the picture and reads `None` until the next module.

> [!TIP]
> **Try it — ask ztunnel who is in the mesh**
>
> ```sh
> istioctl ztunnel-config workload | grep ambient-demo
> ```
>
> Expect something like:
>
> ```text
> NAMESPACE     POD NAME                                   ADDRESS      NODE                     WAYPOINT  PROTOCOL
> ambient-demo  notification-service-v1-6c8f9d7b5c-t7wqx   10.244.0.11  astro-...-control-plane  None      HBONE
> ambient-demo  tester-5b7d9c4f88-k2vnm                    10.244.0.12  astro-...-control-plane  None      HBONE
> ```
>
> `PROTOCOL HBONE` on both workloads is the membership check, and it is the one to reach for reflexively in ambient mode. Run the same command before enrolling on a fresh playground and both rows read `TCP` — the label is the only thing that changed.

A second command is worth knowing alongside it. `istioctl ztunnel-config certificate` shows the workload certificates ztunnel holds, which is how you confirm identities are actually being issued rather than just planned.

> [!TIP]
> **Try it — confirm identities were issued**
>
> ```sh
> istioctl ztunnel-config certificate | grep -E 'CERTIFICATE|ambient-demo' | head -5
> ```
>
> Expect something like:
>
> ```text
> CERTIFICATE NAME                                          TYPE     STATUS  VALID CERT  SERIAL NUMBER
> spiffe://cluster.local/ns/ambient-demo/sa/default         Leaf     Available  true     1f4a...
> spiffe://cluster.local/ns/ambient-demo/sa/default         Root     Available  true     8c22...
> ```
>
> Those are SPIFFE IDs — the standard format Istio issues workload certificates under. Read `spiffe://cluster.local/ns/ambient-demo/sa/default` as: trust domain `cluster.local`, namespace `ambient-demo`, service account `default`. A `Leaf` certificate marked available means `istiod` signed an identity for that service account and ztunnel is holding it ready to use.

## Watching the tunnel carry real traffic

Configuration saying `HBONE` is one thing; a connection actually using it is another. ztunnel is an ordinary pod, so its logs are an ordinary `kubectl logs`, and each proxied connection produces a line naming both peers' identities.

> [!TIP]
> **Try it — generate traffic and read the tunnel's log**
>
> ```sh
> kubectl -n ambient-demo exec deploy/tester -- \
>   curl -s -o /dev/null -w '%{http_code}\n' http://notification-service/
> kubectl -n istio-system logs ds/ztunnel --tail=20 | grep ambient-demo
> ```
>
> Expect something like:
>
> ```text
> 200
>
> 2026-09-27T09:14:22.104Z  INFO access: connection complete
>   src.addr=10.244.0.12:41244 src.workload="tester-5b7d9c4f88-k2vnm"
>   src.identity="spiffe://cluster.local/ns/ambient-demo/sa/default"
>   dst.addr=10.244.0.11:15008 dst.workload="notification-service-v1-6c8f9d7b5c-t7wqx"
>   dst.identity="spiffe://cluster.local/ns/ambient-demo/sa/default"
>   direction="inbound" bytes_sent=853 bytes_recv=76 duration="3ms"
> ```
>
> Exact field names and formatting vary by version; the shape is the point. Both ends have a cryptographic identity, and the destination port is **15008** — ztunnel's HBONE port from Part 1 — not nginx's port 80. The application sent a plain HTTP request to port 80 and never learned it travelled through an authenticated tunnel.

## Where ztunnel stops

ztunnel operates at **L4**. It knows the connection's source and destination identities, addresses and ports. Within that, it can:

- establish and terminate mutual TLS transparently;
- enforce an `AuthorizationPolicy` that matches on **principals, namespaces, IP blocks or ports**;
- report L4 telemetry — bytes, connections, durations.

It **cannot read HTTP**, because it is not an HTTP proxy. Everything that depends on a method, a path, a header or a status code is outside what it can do:

| ztunnel can do (L4) | Needs a waypoint (L7) |
| --- | --- |
| mTLS between workloads | HTTP routing and traffic splitting |
| Deny by source identity | Deny by HTTP method or path |
| Deny by port | Header manipulation |
| Connection-level telemetry | Retries, timeouts, circuit breaking |
| | Request-level telemetry |

The failure mode matters more than the list. Applying an `AuthorizationPolicy` that matches on `methods: ["GET"]` to an ambient namespace with no waypoint does **not** fail loudly. The policy is accepted, stored, and reports healthy — and there is nothing in the request path able to evaluate it. That silent no-op is the single most common ambient-mode mistake, and the next module opens by demonstrating it.

> [!WARNING]
> **Common pitfalls**
>
> - **Grepping for `istio-proxy` to check membership.** Ambient pods never have a sidecar. Use `istioctl ztunnel-config workload` and read the `PROTOCOL` column.
> - **Labelling a namespace for both modes.** `istio-injection=enabled` and `istio.io/dataplane-mode=ambient` on one namespace is a contradiction. Pick one mode per namespace.
> - **Expecting L7 behaviour from ztunnel.** HTTP routing and L7 authorization need a waypoint. Without one, the configuration is accepted and silently does nothing.
> - **Assuming `istio-cni` replaces your cluster CNI.** It chains onto the existing plugin. Where a cluster's CNI does not tolerate chaining, pods end up unable to reach anything — check `istio-cni-node` logs before blaming Istio configuration.
> - **Migrating a namespace from sidecar to ambient without a restart.** Removing the injection label and adding the ambient label enrolls it immediately, but the existing pods keep their now-redundant sidecars until they are recreated.
> - **Sizing ztunnel like a sidecar.** One ztunnel serves every enrolled pod on its node. Its limits are a node-wide concern, not a per-workload one.

## Operational considerations

**Un-enrolling is as cheap as enrolling.** `kubectl label namespace <ns> istio.io/dataplane-mode-` removes the workloads from the mesh, again with no restart. That makes ambient a genuinely reversible change, which is rarely true of sidecar injection — and it makes a staged rollout easy to abandon.

**A single pod can be enrolled.** The same `istio.io/dataplane-mode` label works on a pod, which is useful for testing enrollment against one workload before committing a namespace.

**ztunnel is a shared, node-level dependency.** One proxy serves every enrolled pod on the node, so its resource limits and its failures have node-wide blast radius. That is the trade for not running eighty Envoys, and it is worth understanding before sizing it.

**Mixed meshes work and need discipline.** Sidecar and ambient namespaces interoperate — same identities, same control plane. Keeping track of which namespace is in which mode is a documentation problem; `istioctl ztunnel-config workload` across namespaces is the fastest inventory.

> *Enrollment is a label with no restart because nothing inside the pod changes — and ztunnel gives you identity, encryption and L4 policy, but cannot read a single HTTP header.*

## Reference

- [Ambient data plane modes](https://istio.io/v1.30/docs/ambient/usage/add-workloads/) — the enrollment labels, at namespace and pod scope.
- [ztunnel architecture](https://istio.io/v1.30/docs/ambient/architecture/ztunnel/) — what the node proxy enforces and what it delegates.
- [L4 authorization in ambient](https://istio.io/v1.30/docs/ambient/usage/l4-policy/) — which `AuthorizationPolicy` fields work without a waypoint.
- [SPIFFE identity format](https://spiffe.io/docs/latest/spiffe-about/spiffe-concepts/) — reading the identities in ztunnel's logs.
