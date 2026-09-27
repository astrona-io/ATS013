# Solution Walkthrough

Follow these steps to enroll a namespace in the ambient mesh without recreating anything.

---

## Step 1: Note What You Must Not Change

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

Those UIDs are the grader's record of the pods that existed before enrollment. Every one of them must still be there afterwards — which means no `rollout restart`, no `kubectl delete pod`, no edit to a pod template.

Check the data plane you are about to join:

```sh
kubectl -n istio-system get daemonset
```

```text
NAME             DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   AGE
istio-cni-node   1         1         1       1            1           6m
ztunnel          1         1         1       1            1           6m
```

DaemonSets, not sidecars. Sidecar mode scales proxies with the number of *pods*; ambient mode scales them with the number of *nodes*. On this one-node cluster that is one of each.

---

## Step 2: See That Nothing Is Enrolled Yet

```sh
istioctl ztunnel-config workload --namespace ambient-demo
```

```text
NAMESPACE     POD NAME                                  ADDRESS      NODE                     WAYPOINT  PROTOCOL
ambient-demo  notification-service-6c8f9d7b5c-t7wqx     10.244.0.11  astro-...-control-plane  None      TCP
ambient-demo  tester-5b7d9c4f88-k2vnm                   10.244.0.12  astro-...-control-plane  None      TCP
```

ztunnel already *knows* about every pod on its node — but `PROTOCOL TCP` means plain traffic: these workloads are not in the mesh. That column is the membership check in ambient mode, and it is the one to build a habit around, because counting containers cannot answer the question here.

---

## Step 3: Enroll the Namespace

```sh
kubectl label namespace ambient-demo istio.io/dataplane-mode=ambient
```

```text
namespace/ambient-demo labeled
```

That is the whole operation. No restart, no patch, no waiting.

The reason is mechanical. Sidecar injection is a **mutation of the pod spec**, so it can only happen when a pod is admitted — which is why section 020's labs all needed a `rollout restart`. Ambient enrollment changes **node-level redirection** (programmed by `istio-cni-node`) and **ztunnel's own configuration** (programmed by `istiod`). Both live outside the pod, so the pod does not need to know and does not change.

---

## Step 4: Prove Nothing Was Recreated

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

Same names, `RESTARTS` still 0, `AGE` simply larger, identical UIDs. These workloads now have mutual TLS between them and nothing was recreated to make it happen.

`READY 1/1` — still one container, and it will stay that way. That is the point of the third requirement: in ambient mode a meshed pod is indistinguishable from an unmeshed one by `kubectl get pod`.

---

## Step 5: Confirm With ztunnel

```sh
istioctl ztunnel-config workload --namespace ambient-demo
```

```text
NAMESPACE     POD NAME                                  ADDRESS      NODE                     WAYPOINT  PROTOCOL
ambient-demo  notification-service-6c8f9d7b5c-t7wqx     10.244.0.11  astro-...-control-plane  None      HBONE
ambient-demo  tester-5b7d9c4f88-k2vnm                   10.244.0.12  astro-...-control-plane  None      HBONE
```

`TCP` became `HBONE`. **HBONE** — HTTP-Based Overlay Network Environment — is ambient mode's transport: the original connection is carried inside an mTLS-encrypted HTTP/2 tunnel between ztunnels, so both ends are authenticated and the payload is encrypted.

`WAYPOINT None` is the other half of the picture: these workloads have L4 mesh only, with nothing in the path that can read HTTP. That column is what Module 2 fills in.

---

## Step 6: Watch the Tunnel Carry Traffic

Optional, and worth it once:

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

Both ends carry a cryptographic identity, and the destination port is **15008** — ztunnel's HBONE port — not nginx's port 80. The application sent a plain HTTP request to port 80 and never learned it travelled through an authenticated tunnel.

---

## Step 7: Submit

```sh
astrona submit
```

The grader checks that both ambient DaemonSets are ready, that `ambient-demo` carries `istio.io/dataplane-mode=ambient` and **not** `istio-injection`, that the live pod UIDs are byte-identical to the recorded baseline, that every pod still has exactly one container and no `istio-proxy`, and that `istioctl ztunnel-config workload` reports both workloads with `HBONE`.

---

## Common Mistakes

*   **Running `kubectl rollout restart` out of habit.** It works in the sense that the namespace ends up enrolled, and it fails the lab — the UIDs change. Ambient enrollment needs no restart, and internalising that is the whole point.
*   **Adding `istio-injection=enabled` as well.** A namespace is one mode or the other. The grader rejects both labels being present.
*   **Grepping for `istio-proxy` to check membership.** Ambient pods never have a sidecar. Use `istioctl ztunnel-config workload` and read `PROTOCOL`.
*   **Using `istio.io/dataplane-mode=enabled`.** The value is `ambient`.
*   **Deleting the `lab-baseline` ConfigMap while tidying up.** It is the grader's record; without it the check cannot run.
*   **Expecting L7 behaviour.** ztunnel is L4 only. An `AuthorizationPolicy` matching on an HTTP method here would be accepted and silently do nothing — which is exactly what Module 2 is about.
