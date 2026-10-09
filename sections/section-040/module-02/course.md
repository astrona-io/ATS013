# Add A Waypoint Proxy For L7 In Ambient Mode

Astronaut, in ambient mode the relay towers (ztunnel) give every ship mutual TLS and identity checks for the price of one proxy per node. But a relay tower only checks the envelope: who sent the signal and on which channel. It cannot open the letter. As soon as a rule talks about an HTTP path, a method, a header, a retry or a timeout, something in the path must read HTTP.

That something is a **waypoint proxy**: a checkpoint station you build only where someone must read the signal's contents. It is an Envoy proxy you add per namespace or per service, only where layer 7 (HTTP-aware) behaviour is needed. This module starts with the failure you get when the waypoint is missing, because that failure is silent.

## Learning objectives

After this module you can:

- Explain why an `HTTPRoute` in an ambient namespace with no waypoint is accepted and has no effect.
- Name the Kubernetes object `istioctl waypoint apply` creates, and the field that makes it a waypoint.
- Describe the path a request takes from the client pod to the destination pod once a waypoint is in place.
- Deploy a namespace waypoint, enroll workloads to it, and confirm the routing from ztunnel's own view.
- Apply a Gateway API `HTTPRoute` through a waypoint and prove layer 7 processing from the response.
- Tell a namespace waypoint from a service waypoint, and say which behaviour survives if a waypoint is deleted.

## Before you start

Every mission starts with a pre-flight check, astronaut. Make sure you have the knowledge this module expects, and know what is waiting in your playground.

### What you should already know

- **Ambient mode basics.** The label `istio.io/dataplane-mode=ambient` puts a namespace in the ambient mesh with no pod restart. ztunnel, one proxy per node, then carries its traffic in a mutual TLS tunnel called HBONE.
- **Reading ztunnel.** `istioctl ztunnel-config workload` lists the workloads ztunnel knows; `PROTOCOL HBONE` means a workload is in the mesh.
- **The layer 4 limit.** ztunnel works at layer 4 (identities and ports). It cannot read HTTP methods, paths or headers, so rules that need them are accepted and silently ignored unless a waypoint is in the path.

### What is in your playground

Your playground is a training solar system: a single-node `kind` cluster with **`istioctl` 1.30.5**, **Istio 1.30.5 with the `ambient` profile**, and the **Gateway API CRDs v1.5.1**, installed separately. Istio does not ship these CRDs (Custom Resource Definitions, new forms the cluster's registry office learns to accept). A waypoint *is* a Gateway API `Gateway`, so without them nothing in this module works.

The planet **`ambient-l7`** is **already enrolled** in ambient mode. It runs two ships:

| Ship | Its role |
| --- | --- |
| `notification-service` (Deployment `notification-service-v1`, nginx) | A ship that answers every signal, behind the `notification-service` Service on port `80` |
| `tester` (curl) | Your test shuttle: you send test signals from here |

The layer 4 mesh already works. There is no waypoint and no `HTTPRoute`. All commands run from your normal shell, with `kubectl` already pointed at the cluster.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## The parts of this module

1. [What A Waypoint Is And How Traffic Reaches It](./course-01-what-a-waypoint-is.md): the silent no-op of an `HTTPRoute` with no waypoint, the `Gateway` behind `istioctl waypoint apply`, the field that makes it a waypoint, and the path a request takes once one exists.
2. [L7 Configuration Through A Waypoint](./course-02-l7-configuration-through-a-waypoint.md): watching the same route take effect, reading the route's status honestly, and finding the route inside the waypoint's Envoy.
   - Mission: [Waypoint Proxy For L7](./labs/lab-01/question.md)
3. [Scoping And Removing Waypoints](./course-03-scoping-and-removing-waypoints.md): namespace waypoints versus service waypoints, what survives when a waypoint is deleted, and the running costs of the extra hop.
4. [Wrap-Up: Mission Debrief](./course-04-wrap-up.md)

## Why this matters

In sidecar mode every workload had one Envoy that did everything, layer 4 and layer 7 together, whether it needed the layer 7 half or not. Ambient mode splits that: ztunnel handles layer 4 for everyone at low cost, and a waypoint handles layer 7 only for the namespaces and services that ask for it.

That split means layer 7 is now something you can forget to provide. In sidecar mode that never happened, because the Envoy was always there. Most ambient-mode confusion comes from this one change, and the exam expects you to add a waypoint and prove it is in the path.
