# Enrollment, Verification And The L4 Boundary

Your playground has a running ambient data plane, and no namespace is in the mesh yet. Adding workloads to the mesh is called **enrollment**. In sidecar mode it means creating every pod again; in ambient mode it does not. This part shows how to enroll a namespace, how to prove the enrollment worked when the pods look exactly the same, and which features ztunnel cannot give you on its own.

## Enrollment is a label, and nothing restarts

A namespace joins the ambient mesh through one label on the namespace: `istio.io/dataplane-mode=ambient`. It applies to every pod in the namespace, new or already running. Three components react to the label:

- `istiod`, the control plane, tells the ztunnel on each node about the namespace's workloads.
- `istio-cni-node`, the node agent, sets up the traffic redirect for those pods.
- `ztunnel`, the per-node layer 4 proxy, starts carrying their traffic through its mutual TLS (mTLS) tunnel.

### Sidecar mode and ambient mode side by side

The difference from sidecar mode is the main practical argument for ambient mode, so it is worth comparing the two directly:

| | Sidecar mode | Ambient mode |
| --- | --- | --- |
| What changes | The **pod spec**: a container is added | The node-level redirect and ztunnel's state |
| When it is decided | When the pod is created, by an admission webhook | At any time, by the control plane |
| To apply it to running pods | Create every pod again | Nothing |
| To undo it | Create every pod again | Nothing |

Sidecar injection changes the pod spec, so it can only happen when the pod is created. A mutating admission webhook does it: the Kubernetes API server calls the webhook, and the webhook can change the pod before the API server stores it. Ambient enrollment changes things that live *outside* the pod spec, so the pod does not change at all.

The pod's `AGE` column proves this. List the pods, label the namespace, and list the pods again:

<!-- astrona:playground:renew -->

```sh
kubectl -n ambient-demo get pods
kubectl label namespace ambient-demo istio.io/dataplane-mode=ambient
kubectl -n ambient-demo get pods
```

The output looks like this:

```text
NAME                                       READY   STATUS    RESTARTS   AGE
notification-service-v1-6c8f9d7b5c-t7wqx   1/1     Running   0          6m
tester-5b7d9c4f88-k2vnm                    1/1     Running   0          6m

namespace/ambient-demo labeled

NAME                                       READY   STATUS    RESTARTS   AGE
notification-service-v1-6c8f9d7b5c-t7wqx   1/1     Running   0          6m12s
tester-5b7d9c4f88-k2vnm                    1/1     Running   0          6m12s
```

The pod names are the same, `RESTARTS` is still 0, and `AGE` is twelve seconds higher. Traffic between these workloads now uses mTLS, and no pod was created again. `READY 1/1` means there is still one container, and it stays that way.

## Checking membership when containers do not tell you

That last point creates a new problem. In sidecar mode, `kubectl get pod` answered the question "is this pod in the mesh?": two containers meant yes. In ambient mode every pod in the mesh still has exactly one container. So the container count does not just fail to help, it **misleads**. A colleague who searches for `istio-proxy` will decide that the mesh is broken, and may try to "fix" it.

### Ask ztunnel instead

The right question is what ztunnel knows, and `istioctl ztunnel-config workload` asks it. This command prints the workloads a running ztunnel holds in its configuration, the same way `istioctl proxy-config` prints what an Envoy sidecar holds.

The `PROTOCOL` column gives the answer:

- **`HBONE`**: the workload is in the mesh. Traffic to it goes through the mTLS tunnel on port 15008. HBONE (HTTP-Based Overlay Network Environment) is the HTTP/2 tunnel, protected by mTLS, that ztunnel uses to carry traffic between workloads.
- **`TCP`**: plain traffic. The workload is not enrolled, or the mesh does not manage it.

The `WAYPOINT` column reads `None` for now. It matters only once you add a waypoint proxy, the Envoy proxy that does layer 7 (HTTP) work.

Ask ztunnel which `ambient-demo` workloads it carries:

```sh
istioctl ztunnel-config workload | grep ambient-demo
```

The output looks like this:

```text
NAMESPACE     POD NAME                                   ADDRESS      NODE                     WAYPOINT  PROTOCOL
ambient-demo  notification-service-v1-6c8f9d7b5c-t7wqx   10.244.0.11  astro-...-control-plane  None      HBONE
ambient-demo  tester-5b7d9c4f88-k2vnm                    10.244.0.12  astro-...-control-plane  None      HBONE
```

`PROTOCOL HBONE` on both workloads is the membership check. On a fresh playground, before you add the label, both rows read `TCP`. The label is the only thing that changed.

> [!TIP]
> Make `istioctl ztunnel-config workload` your first check in ambient mode. Whenever someone asks "is this in the mesh?", read the `PROTOCOL` column, never the container count.

### Check that identities were issued

Membership is one half of the proof; the other half is identity. `istioctl ztunnel-config certificate` shows the workload certificates that ztunnel holds. `istiod` signs one certificate per service account, and ztunnel uses it for mTLS on behalf of the pods. The command confirms that `istiod` really issued the identities.

Look for the certificates for `ambient-demo`:

```sh
istioctl ztunnel-config certificate | grep -E 'CERTIFICATE|ambient-demo' | head -5
```

The output looks like this (shortened):

```text
CERTIFICATE NAME                                          TYPE     STATUS  VALID CERT  SERIAL NUMBER
spiffe://cluster.local/ns/ambient-demo/sa/default         Leaf     Available  true     1f4a...
spiffe://cluster.local/ns/ambient-demo/sa/default         Root     Available  true     8c22...
```

Those names are SPIFFE (Secure Production Identity Framework For Everyone) IDs, the standard format Istio uses for workload identities. Read `spiffe://cluster.local/ns/ambient-demo/sa/default` as: trust domain `cluster.local`, namespace `ambient-demo`, service account `default`. A `Leaf` certificate marked `Available` means `istiod` signed an identity for that service account, and ztunnel holds it ready to use.

## Watching the tunnel carry real traffic

Configuration that says `HBONE` is one thing; a real connection that uses the tunnel is another. ztunnel runs as an ordinary pod, so you read its log with an ordinary `kubectl logs`. Every connection ztunnel carries writes an access log line with the identities of both sides.

Send one request from `tester` to `notification-service`, then read ztunnel's log:

```sh
kubectl -n ambient-demo exec deploy/tester -- \
  curl -s -o /dev/null -w '%{http_code}\n' http://notification-service/
kubectl -n istio-system logs ds/ztunnel --tail=20 | grep ambient-demo
```

The output looks like this (shortened):

```text
200

2026-09-27T09:14:22.104Z  INFO access: connection complete
  src.addr=10.244.0.12:41244 src.workload="tester-5b7d9c4f88-k2vnm"
  src.identity="spiffe://cluster.local/ns/ambient-demo/sa/default"
  dst.addr=10.244.0.11:15008 dst.workload="notification-service-v1-6c8f9d7b5c-t7wqx"
  dst.identity="spiffe://cluster.local/ns/ambient-demo/sa/default"
  direction="inbound" bytes_sent=853 bytes_recv=76 duration="3ms"
```

The exact field names and layout change between versions, so read the fields, not their position. Both sides have a cryptographic identity. The destination port is **15008**, the HBONE port, not nginx's port 80. The application sent a plain HTTP request to port 80 and never learned that ztunnel carried it through an mTLS tunnel.

## Where ztunnel stops

The log line also shows the limit of ztunnel: it records connections and bytes, not HTTP paths or status codes. ztunnel works at **layer 4**, the transport layer. It sees the source and destination identities, the addresses and the ports. It never reads the HTTP request inside the connection.

### What ztunnel can and cannot do

Within layer 4, ztunnel can:

- set up and end mTLS without the applications knowing;
- enforce an `AuthorizationPolicy` (the Istio resource that allows or denies requests) that matches on **principals, namespaces, IP blocks or ports**;
- report layer 4 telemetry: bytes, connections and durations.

It **cannot read HTTP**, because it is not an HTTP proxy. Anything that depends on a method, a path, a header or a status code is layer 7, and needs a waypoint proxy:

| ztunnel can do (layer 4) | Needs a waypoint (layer 7) |
| --- | --- |
| mTLS between workloads | HTTP routing and traffic splitting |
| Deny by source identity | Deny by HTTP method or path |
| Deny by port | Header changes |
| Connection-level telemetry | Retries, timeouts, circuit breaking |
| | Request-level telemetry |

### The silent failure

How a layer 7 rule fails matters more than the list. Suppose you apply an `AuthorizationPolicy` that matches on `methods: ["GET"]` to an ambient namespace with no waypoint. The API server accepts the policy and stores it, and nothing reports an error. But no component in the request's path can evaluate an HTTP method, so the rule has no effect. That silent failure is the most common mistake in ambient mode, and a waypoint proxy is what closes the gap.

## Operational considerations

A few more facts help when you run ambient mode for real. Each one follows from the fact that enrollment lives outside the pod spec.

**Removing a namespace is as cheap as adding it.** `kubectl label namespace <ns> istio.io/dataplane-mode-` takes the workloads out of the mesh, again with no restart. That makes ambient mode easy to undo, which is rarely true of sidecar injection, and it makes a step-by-step rollout easy to stop.

**You can enroll a single pod.** The same `istio.io/dataplane-mode` label works on a pod. That is useful for testing one workload before you enroll a whole namespace.

**ztunnel is shared by the whole node.** One ztunnel serves every pod in the mesh on its node, so its resource limits and its failures affect the whole node. That is the price for not running eighty Envoy proxies, so size it with care.

**Mixed meshes work, but need care.** Sidecar namespaces and ambient namespaces can talk to each other: they share the same identities and the same control plane. You must keep track of which namespace uses which mode, and `istioctl ztunnel-config workload` across all namespaces is the fastest list.

You now know that enrollment is one label with no restart, because nothing in the pod spec changes. You can prove membership with `istioctl ztunnel-config workload`, check identities with `istioctl ztunnel-config certificate`, and see real connections on port 15008 in ztunnel's log. ztunnel gives you identity, encryption and layer 4 policy, but it cannot read a single HTTP header. The open question is how to add layer 7 features where you need them, which is the job of a waypoint proxy.

## Common pitfalls

> [!WARNING]
> **Searching for `istio-proxy` to check membership.** Ambient pods never have a sidecar. Use `istioctl ztunnel-config workload` and read the `PROTOCOL` column.
>
> **Labelling a namespace for both modes.** `istio-injection=enabled` and `istio.io/dataplane-mode=ambient` on one namespace contradict each other. Pick one mode per namespace.
>
> **Expecting layer 7 behaviour from ztunnel.** HTTP routing and layer 7 authorization need a waypoint. Without one, the API server accepts the configuration and it silently does nothing.
>
> **Assuming `istio-cni` replaces your cluster's network plugin.** It chains onto the existing plugin. Where a cluster's plugin does not allow chaining, pods cannot reach anything. Check the `istio-cni-node` logs before you blame the Istio configuration.
>
> **Moving a namespace from sidecar to ambient without a restart.** Removing the injection label and adding the ambient label enrolls the namespace right away. But the existing pods keep their sidecars, which are no longer needed, until they are created again.
>
> **Sizing ztunnel like a sidecar.** One ztunnel serves every pod in the mesh on its node. Its limits are a concern for the whole node, not for one workload.

## Your mission: Install Istio In Ambient Mode Lab

You can now enroll a namespace in ambient mode and prove its membership with ztunnel. The lab asks you to enroll a namespace without creating any pod again and without sidecars, and to show that ztunnel carries both workloads over HBONE.

The lab runs on its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-013-playground-040-01
```

Then start the lab. The task is on the next page; solve it on your own first:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-040/module-01/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-013-lab-040-01
astrona start ats-013-playground-040-01
```
