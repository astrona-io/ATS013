# Add A Waypoint Proxy For L7 In Ambient Mode

In ambient mode, ztunnel gives every workload mutual TLS (Transport Layer Security) and identity checks with one proxy per node. ztunnel works at layer 4 (L4): it sees who opened a connection and to which port, but it does not read the HTTP (Hypertext Transfer Protocol) request inside it. As soon as a rule talks about an HTTP path, a method, a header, a retry or a timeout, something in the path must read HTTP.

That component is a **waypoint proxy**: an Envoy proxy that you add per namespace or per Service, only where layer 7 (L7, HTTP-aware) behaviour is needed. This module starts with the failure you get when the waypoint is missing, because that failure gives no error. Then it shows how to add a waypoint, how to prove that it handles the traffic, and how to scope or remove it.

## Learning objectives

After this module you can:

- Explain why an `HTTPRoute` in an ambient namespace with no waypoint is accepted and has no effect.
- Name the Kubernetes object `istioctl waypoint apply` creates, and the field that makes it a waypoint.
- Describe the path a request takes from the client pod to the destination pod once a waypoint is in place.
- Deploy a namespace waypoint, enroll workloads to it, and confirm the routing from ztunnel's own view.
- Apply a Gateway API `HTTPRoute` through a waypoint and prove layer 7 processing from the response.
- Tell a namespace waypoint from a service waypoint, scope a waypoint to one Service, and say which behaviour remains if a waypoint is deleted.

## Before you start

This module builds on a working ambient mesh. You add layer 7 on top of it; you do not install it.

### What you should already know

- **Ambient mode basics.** The label `istio.io/dataplane-mode=ambient` puts a namespace in the ambient mesh with no pod restart. ztunnel, one proxy per node, then carries the namespace's traffic in a mutual TLS tunnel called HBONE (HTTP-Based Overlay Network Environment).
- **Reading ztunnel.** `istioctl ztunnel-config workload` lists the workloads ztunnel knows; `PROTOCOL HBONE` means a workload is in the mesh.
- **The layer 4 limit.** ztunnel works with identities and ports. It cannot read HTTP methods, paths or headers, so rules that need them are accepted and ignored unless a waypoint is in the path.

### What is in your playground

The playground is a single-node `kind` cluster with **`istioctl` 1.30.5**, **Istio 1.30.5 with the `ambient` profile**, and the **Gateway API CRDs v1.5.1**. A CRD (Custom Resource Definition) adds a new object kind to the Kubernetes API. Istio does not ship the Gateway API CRDs, so the playground installs them separately. A waypoint *is* a Gateway API `Gateway`, so without them nothing in this module works.

The namespace **`ambient-l7`** is **already enrolled** in ambient mode. It runs two workloads:

| Workload | What it is |
| --- | --- |
| `notification-service` (Deployment `notification-service-v1`, nginx) | A web server that answers every request, behind the `notification-service` Service on port `80` |
| `tester` (curl) | The client pod; every test request is sent from here |

The layer 4 mesh already works. There is no waypoint and no `HTTPRoute`. You run every command from your normal shell, and `kubectl` already points at the cluster.

Start your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Read the parts in this order:

1. **What A Waypoint Is And How Traffic Reaches It:** an `HTTPRoute` that does nothing without a waypoint, the `Gateway` behind `istioctl waypoint apply`, the field that makes it a waypoint, and the path a request takes once one exists.
2. **L7 Configuration Through A Waypoint:** the same route taking effect, what the route's status does and does not prove, and how to find the route inside the waypoint's Envoy. The graded lab "Waypoint Proxy For L7" follows this part.
3. **Scoping And Removing Waypoints:** namespace waypoints and service waypoints, what remains when a waypoint is deleted, and the running costs of the extra hop. The graded lab "Scope A Waypoint To One Service" follows this part.

A summary closes the module.
