# Solution Walkthrough

Follow these steps to add the `ambient-demo` namespace to the ambient mesh without creating any pod again, and to prove it with ztunnel, the per-node layer 4 proxy of ambient mode.

---

## Step 1: Note what you must not change

List the pods and read the baseline the grader saved:

```sh
kubectl -n ambient-demo get pods
kubectl -n ambient-demo get configmap lab-baseline -o jsonpath='{.data.pod-uids}{"\n"}'
```

```text
NAME                                    READY   STATUS    RESTARTS   AGE
notification-service-6c8f9d7b5c-t7wqx   1/1     Running   0          5m
tester-5b7d9c4f88-k2vnm                 1/1     Running   0          5m

notification-service-6c8f9d7b5c-t7wqx=9a1c...-...
tester-5b7d9c4f88-k2vnm=4e77...-...
```

A UID is the unique ID Kubernetes gives each object when it is created; a pod that is created again gets a new one. Those UIDs are the grader's record of the pods that existed before enrollment. Every one of them must still be there at the end. So: no `rollout restart`, no `kubectl delete pod`, and no edit to a pod template.

Now check the data plane you are about to join:

```sh
kubectl -n istio-system get daemonset
```

```text
NAME             DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   AGE
istio-cni-node   1         1         1       1            1           6m
ztunnel          1         1         1       1            1           6m
```

These are DaemonSets, not sidecars. A DaemonSet is a workload that Kubernetes runs once on every node. Sidecar mode adds a proxy for every *pod*; ambient mode adds one for every *node*. This cluster has one node, so there is one of each.

---

## Step 2: See that nothing is enrolled yet

Ask ztunnel what it knows about `ambient-demo`:

```sh
istioctl ztunnel-config workload | grep ambient-demo
```

```text
NAMESPACE     POD NAME                                  ADDRESS      NODE                     WAYPOINT  PROTOCOL
ambient-demo  notification-service-6c8f9d7b5c-t7wqx     10.244.0.11  astro-...-control-plane  None      TCP
ambient-demo  tester-5b7d9c4f88-k2vnm                   10.244.0.12  astro-...-control-plane  None      TCP
```

ztunnel already *knows* every pod on its node. But `PROTOCOL TCP` means plain traffic: these workloads are not in the mesh. This column is the membership check in ambient mode, because counting containers cannot answer the question.

---

## Step 3: Enroll the namespace

Add the ambient label to the namespace:

```sh
kubectl label namespace ambient-demo istio.io/dataplane-mode=ambient
```

```text
namespace/ambient-demo labeled
```

That is the whole job. There is no restart, no patch and no waiting.

Here is why. Sidecar injection changes the **pod spec**, so it can only happen when a pod is created; that is why sidecar mode always needs a `rollout restart`. Ambient enrollment changes the **node-level redirect**, which `istio-cni-node` sets up, and **ztunnel's own configuration**, which `istiod` (the Istio control plane) sends. Both live outside the pod, so the pod does not need to know and does not change.

---

## Step 4: Prove that no pod was created again

List the pods again, and compare the live UIDs with the baseline:

```sh
kubectl -n ambient-demo get pods
diff <(kubectl -n ambient-demo get configmap lab-baseline -o jsonpath='{.data.pod-uids}') \
     <(kubectl -n ambient-demo get pods -o jsonpath='{range .items[*]}{.metadata.name}={.metadata.uid}{"\n"}{end}' | sort) \
  && echo "identical - no pod was recreated"
```

```text
NAME                                    READY   STATUS    RESTARTS   AGE
notification-service-6c8f9d7b5c-t7wqx   1/1     Running   0          7m12s
tester-5b7d9c4f88-k2vnm                 1/1     Running   0          7m12s

identical - no pod was recreated
```

The names are the same, `RESTARTS` is still 0, `AGE` is simply higher, and the UIDs match. Traffic between these workloads now uses mutual TLS (mTLS), and no pod was created again.

`READY 1/1` means there is still one container, and it stays that way. That is the point of the third requirement: in ambient mode, `kubectl get pod` cannot tell a meshed pod from one outside the mesh.

---

## Step 5: Confirm with ztunnel

Ask ztunnel again:

```sh
istioctl ztunnel-config workload | grep ambient-demo
```

```text
NAMESPACE     POD NAME                                  ADDRESS      NODE                     WAYPOINT  PROTOCOL
ambient-demo  notification-service-6c8f9d7b5c-t7wqx     10.244.0.11  astro-...-control-plane  None      HBONE
ambient-demo  tester-5b7d9c4f88-k2vnm                   10.244.0.12  astro-...-control-plane  None      HBONE
```

`TCP` became `HBONE`. **HBONE** (HTTP-Based Overlay Network Environment) is the tunnel ambient mode uses between workloads: ztunnel carries the original connection inside an HTTP/2 tunnel protected by mTLS, on port 15008. Both sides check each other's certificate, and the traffic is encrypted.

`WAYPOINT None` means these workloads have layer 4 mesh only: nothing in the path can read HTTP. A waypoint proxy, the Envoy proxy that does layer 7 work in ambient mode, would fill in that column.

---

## Step 6: Watch the tunnel carry traffic

This step is optional, but worth doing once. Send a request from `tester`, then read ztunnel's log:

```sh
kubectl -n ambient-demo exec deploy/tester -- \
  curl -s -o /dev/null -w '%{http_code}\n' http://notification-service/
kubectl -n istio-system logs ds/ztunnel --tail=20 | grep ambient-demo | head -2
```

```text
200

2026-09-27T09:14:22.104Z INFO access: connection complete
  src.workload="tester-5b7d9c4f88-k2vnm"
  src.identity="spiffe://cluster.local/ns/ambient-demo/sa/default"
  dst.addr=10.244.0.11:15008
  dst.identity="spiffe://cluster.local/ns/ambient-demo/sa/default"
```

Both sides carry a cryptographic identity, and the destination port is **15008**, the HBONE port, not nginx's port 80. The application sent a plain HTTP request to port 80 and never learned that ztunnel carried it through an mTLS tunnel.

---

## Step 7: Submit

Send the lab for grading:

```sh
astrona submit
```

The grader checks that:

- both ambient DaemonSets have ready pods;
- `ambient-demo` carries `istio.io/dataplane-mode=ambient` and **not** `istio-injection`;
- the live pod UIDs exactly match the saved baseline;
- every pod still has exactly one container, and none is `istio-proxy`;
- `istioctl ztunnel-config workload` reports both workloads with `HBONE`.

---

## Common mistakes

*   **Running `kubectl rollout restart` out of habit.** The namespace ends up enrolled, but the lab fails because the UIDs change. Ambient enrollment needs no restart, and that is the whole point.
*   **Adding `istio-injection=enabled` as well.** A namespace uses one mode or the other. The grader rejects both labels together.
*   **Searching for `istio-proxy` to check membership.** Ambient pods never have a sidecar. Use `istioctl ztunnel-config workload` and read `PROTOCOL`.
*   **Using `istio.io/dataplane-mode=enabled`.** The value is `ambient`.
*   **Deleting the `lab-baseline` ConfigMap while tidying up.** It is the grader's record; without it the check cannot run.
*   **Expecting layer 7 behaviour.** ztunnel works at layer 4 only. An `AuthorizationPolicy` that matches on an HTTP method would be accepted here and silently do nothing.
