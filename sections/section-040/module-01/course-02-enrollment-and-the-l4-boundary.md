# Enrollment, Verification And The L4 Boundary

Your playground has a running ambient data plane, and nothing is enrolled yet. In this part you join a planet (namespace) to the mesh and see that no ship has to relaunch. Then you learn a membership check that actually works in ambient mode, and you find the line ztunnel cannot cross.

## Enrollment is a label, and nothing restarts

A namespace joins the ambient mesh through one label: `istio.io/dataplane-mode=ambient`. Think of it as a planet-wide order: every ship here, new or already flying, now uses the relay towers. Three components react to it:

- `istiod` (mission control) tells the ztunnel on each node about the namespace's workloads.
- `istio-cni-node` (the dock crew) sets up the redirect for those pods.
- `ztunnel` (the relay tower) starts carrying their traffic through the tunnel.

### Sidecar mode and ambient mode side by side

The difference between the two modes is the main practical argument for ambient mode, so compare them directly:

| | Sidecar mode | Ambient mode |
| --- | --- | --- |
| What changes | The **pod spec**: a container is added | **Node-level** redirect and ztunnel's state |
| When it is decided | When the pod is created, by an admission webhook | All the time, by the control plane |
| To apply it to running pods | Recreate every pod | Nothing |
| To undo it | Recreate every pod again | Nothing |

Sidecar injection changes the pod spec, so it can only happen when the pod is admitted (created). An admission webhook is a dock inspector the registry office calls before it files a new ship. Ambient enrollment changes things that live *outside* the pod, so the pod does not need to know and does not change.

You can see the proof in the pod's `AGE`: note it before you enroll, and watch it keep counting up afterwards.

<!-- astrona:playground:renew -->

### See it in your playground

List the pods, label the namespace, and list the pods again:

```sh
kubectl -n ambient-demo get pods
kubectl label namespace ambient-demo istio.io/dataplane-mode=ambient
kubectl -n ambient-demo get pods
```

Expect something like:

```text
NAME                                       READY   STATUS    RESTARTS   AGE
notification-service-v1-6c8f9d7b5c-t7wqx   1/1     Running   0          6m
tester-5b7d9c4f88-k2vnm                    1/1     Running   0          6m

namespace/ambient-demo labeled

NAME                                       READY   STATUS    RESTARTS   AGE
notification-service-v1-6c8f9d7b5c-t7wqx   1/1     Running   0          6m12s
tester-5b7d9c4f88-k2vnm                    1/1     Running   0          6m12s
```

The pod names are the same, `RESTARTS` is still 0, and `AGE` is twelve seconds higher. These workloads now use mutual TLS between them, and nothing was recreated. `READY 1/1` means there is still one container, and it stays that way.

## Checking membership when containers do not tell you

In sidecar mode, `kubectl get pod` answered "is this pod in the mesh?": two containers meant yes. In ambient mode every meshed pod still has exactly one container. So counting containers does not just fail to help, it **misleads**. A colleague who searches for `istio-proxy` will decide the mesh is broken, and may try to "fix" it.

### Ask ztunnel instead

The right question is what ztunnel knows, and `istioctl ztunnel-config workload` asks it. It is the ztunnel version of `istioctl proxy-config`: it prints what a running proxy knows.

The `PROTOCOL` column gives the answer:

- **`HBONE`**: the workload is enrolled. Traffic to it goes through the mTLS tunnel on port 15008. HBONE (HTTP-Based Overlay Network Environment) is the sealed tunnel the relay towers use between them.
- **`TCP`**: plain traffic. The workload is not enrolled, or the mesh does not manage it.

The `WAYPOINT` column reads `None` for now. It only matters once you add a waypoint proxy.

### See it in your playground

Ask ztunnel which `ambient-demo` workloads it carries:

```sh
istioctl ztunnel-config workload | grep ambient-demo
```

Expect something like:

```text
NAMESPACE     POD NAME                                   ADDRESS      NODE                     WAYPOINT  PROTOCOL
ambient-demo  notification-service-v1-6c8f9d7b5c-t7wqx   10.244.0.11  astro-...-control-plane  None      HBONE
ambient-demo  tester-5b7d9c4f88-k2vnm                    10.244.0.12  astro-...-control-plane  None      HBONE
```

`PROTOCOL HBONE` on both workloads is the membership check. Run the same command on a fresh playground before you enroll, and both rows read `TCP`. The label is the only thing that changed.

> [!TIP]
> Make `istioctl ztunnel-config workload` your first reflex in ambient mode. Whenever someone asks "is this in the mesh?", read the `PROTOCOL` column, never the container count.

### Check that identities were issued

A second command is worth knowing. `istioctl ztunnel-config certificate` shows the workload certificates ztunnel holds: the ID badges mission control printed for each ship. It confirms that identities were really issued, not just planned.

Look for the certificates for `ambient-demo`:

```sh
istioctl ztunnel-config certificate | grep -E 'CERTIFICATE|ambient-demo' | head -5
```

Expect something like:

```text
CERTIFICATE NAME                                          TYPE     STATUS  VALID CERT  SERIAL NUMBER
spiffe://cluster.local/ns/ambient-demo/sa/default         Leaf     Available  true     1f4a...
spiffe://cluster.local/ns/ambient-demo/sa/default         Root     Available  true     8c22...
```

Those names are SPIFFE IDs, the standard format Istio uses for workload identities. Read `spiffe://cluster.local/ns/ambient-demo/sa/default` as: trust domain `cluster.local`, namespace `ambient-demo`, service account `default`. A `Leaf` certificate marked `Available` means `istiod` signed an identity for that service account, and ztunnel holds it ready to use.

## Watching the tunnel carry real traffic

The configuration saying `HBONE` is one thing. A real connection using the tunnel is another. ztunnel is an ordinary pod, so its logs are an ordinary `kubectl logs`, and every connection it carries writes a line with both sides' identities.

### See it in your playground

Send one signal from `tester` to `notification-service`, then read ztunnel's log:

```sh
kubectl -n ambient-demo exec deploy/tester -- \
  curl -s -o /dev/null -w '%{http_code}\n' http://notification-service/
kubectl -n istio-system logs ds/ztunnel --tail=20 | grep ambient-demo
```

Expect something like:

```text
200

2026-09-27T09:14:22.104Z  INFO access: connection complete
  src.addr=10.244.0.12:41244 src.workload="tester-5b7d9c4f88-k2vnm"
  src.identity="spiffe://cluster.local/ns/ambient-demo/sa/default"
  dst.addr=10.244.0.11:15008 dst.workload="notification-service-v1-6c8f9d7b5c-t7wqx"
  dst.identity="spiffe://cluster.local/ns/ambient-demo/sa/default"
  direction="inbound" bytes_sent=853 bytes_recv=76 duration="3ms"
```

The exact field names and layout change between versions; the shape is what matters. Both ends have a cryptographic identity. The destination port is **15008**, the HBONE port, not nginx's port 80. The application sent a plain HTTP request to port 80 and never learned that it travelled through a checked tunnel.

## Where ztunnel stops

ztunnel works at **layer 4**, the transport layer. Think of it as checking the envelope: who sent the signal and which channel (port) it uses. It never opens the letter.

### What ztunnel can and cannot do

Within layer 4, ztunnel can:

- set up and end mutual TLS without the applications knowing;
- enforce an `AuthorizationPolicy` (the guard's list at the airlock) that matches on **principals, namespaces, IP blocks or ports**;
- report layer 4 telemetry: bytes, connections and durations.

It **cannot read HTTP**, because it is not an HTTP proxy. Anything that depends on a method, a path, a header or a status code is layer 7, and is outside what it can do:

| ztunnel can do (layer 4) | Needs a waypoint (layer 7) |
| --- | --- |
| mTLS between workloads | HTTP routing and traffic splitting |
| Deny by source identity | Deny by HTTP method or path |
| Deny by port | Header changes |
| Connection-level telemetry | Retries, timeouts, circuit breaking |
| | Request-level telemetry |

### The silent failure

How it fails matters more than the list. Suppose you apply an `AuthorizationPolicy` that matches on `methods: ["GET"]` to an ambient namespace with no waypoint. It does **not** fail loudly. The API server accepts the policy, stores it, and reports it as healthy. But nothing in the signal's path can evaluate it.

That silent no-op is the most common ambient-mode mistake. A waypoint proxy is what closes this gap.

## Operational considerations

A few facts help when you run ambient mode for real. Each one follows from the fact that enrollment lives outside the pod.

**Removing a namespace is as cheap as adding it.** `kubectl label namespace <ns> istio.io/dataplane-mode-` takes the workloads out of the mesh, again with no restart. That makes ambient mode easy to undo, which is rarely true of sidecar injection, and it makes a step-by-step rollout easy to stop.

**You can enroll a single pod.** The same `istio.io/dataplane-mode` label works on a pod. That is useful for testing one workload before you enroll a whole namespace.

**ztunnel is shared by the whole node.** One proxy serves every enrolled pod on the node, so its resource limits and its failures affect the whole node. That is the price for not running eighty Envoy proxies. Keep it in mind when you size it.

**Mixed meshes work, but need care.** Sidecar namespaces and ambient namespaces can talk to each other: same identities, same control plane. Keeping track of which namespace uses which mode is a record-keeping job. `istioctl ztunnel-config workload` across all namespaces is the fastest list.

In short: enrollment is a label with no restart, because nothing inside the pod changes. ztunnel gives you identity, encryption and layer 4 policy, but it cannot read a single HTTP header.

## Common pitfalls

> [!WARNING]
> **Searching for `istio-proxy` to check membership.** Ambient pods never have a sidecar. Use `istioctl ztunnel-config workload` and read the `PROTOCOL` column.
>
> **Labelling a namespace for both modes.** `istio-injection=enabled` and `istio.io/dataplane-mode=ambient` on one namespace contradict each other. Pick one mode per namespace.
>
> **Expecting layer 7 behaviour from ztunnel.** HTTP routing and layer 7 authorization need a waypoint. Without one, the configuration is accepted and silently does nothing.
>
> **Assuming `istio-cni` replaces your cluster's network plugin.** It chains onto the existing plugin. Where a cluster's plugin does not allow chaining, pods cannot reach anything. Check the `istio-cni-node` logs before you blame the Istio configuration.
>
> **Moving a namespace from sidecar to ambient without a restart.** Removing the injection label and adding the ambient label enrolls it right away. But the existing pods keep their sidecars, which are now not needed, until they are recreated.
>
> **Sizing ztunnel like a sidecar.** One ztunnel serves every enrolled pod on its node. Its limits are a node-wide concern, not a per-workload one.

## Your mission: Install Istio In Ambient Mode

You can now enroll a namespace in ambient mode and prove membership with ztunnel. Now prove it in a graded mission: enroll a namespace without recreating a single pod, with no sidecars, and show that ztunnel carries both workloads over HBONE.

The mission runs in its own training solar system, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-013-playground-040-01
```

Then start the mission:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-040/module-01/labs/lab-01
```

Read the task in [`question.md`](./labs/lab-01/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/module-01/labs/lab-01
```

When the mission is done, remove it and wake your playground up again:

```sh
astrona destroy ats-013-lab-040-01
astrona start ats-013-playground-040-01
```
