# Solution Walkthrough

Mission debrief, astronaut. Read this only after you have tried the specification yourself.

---

## Step 1: Sort the Requirements by Layer

The specification really asks one question three times: **which layer enforces this?** ztunnel, the relay tower on each node, checks the envelope (layer 4). The waypoint, the checkpoint station, reads the letter (layer 7).

| Requirement | Enforced by | Needs a waypoint? |
| --- | --- | --- |
| Mesh identity, mutual TLS between workloads | ztunnel | No |
| A rule on source identity or port | ztunnel | No |
| Response header change (`HTTPRoute`) | waypoint | **Yes** |
| A rule on the HTTP **method** | waypoint | **Yes** |

Requirements 6 and 7 are the heart of the exercise. `AuthorizationPolicy` is one kind of object, but a rule that matches on `methods` is layer 7, and a rule that matches on `principals` or `ports` is layer 4. ztunnel enforces the second and cannot even see the first, because it does not read HTTP. Without a waypoint, the policy applies cleanly, reports healthy, and does nothing.

---

## Step 2: Enroll, Without Recreating Anything

Read the baseline, label the namespace, and list the pods:

```sh
kubectl -n ambient-shop get configmap lab-baseline -o jsonpath='{.data.pod-uids}{"\n"}'
kubectl label namespace ambient-shop istio.io/dataplane-mode=ambient
kubectl -n ambient-shop get pods
```

```text
batch-runner-...=a91c...
catalog-api-...=3f42...
storefront-...=7b08...

namespace/ambient-shop labeled

NAME                     READY   STATUS    RESTARTS   AGE
batch-runner-...         1/1     Running   0          6m14s
catalog-api-...          1/1     Running   0          6m14s
storefront-...           1/1     Running   0          6m14s
```

One label, and no restart. `RESTARTS` is still 0, and `AGE` just kept counting.

Be ready to explain why. Sidecar injection changes the **pod spec**, so it can only happen when a pod is created. Ambient enrollment changes the **node-level redirect**, set up by `istio-cni-node`, and **ztunnel's configuration**, sent by `istiod`. Both live outside the pod.

Confirm with ztunnel:

```sh
istioctl ztunnel-config workload | grep ambient-shop
```

```text
NAMESPACE     POD NAME             ADDRESS      NODE     WAYPOINT  PROTOCOL
ambient-shop  batch-runner-...     10.244.0.12  ...      None      HBONE
ambient-shop  catalog-api-...      10.244.0.11  ...      None      HBONE
ambient-shop  storefront-...       10.244.0.13  ...      None      HBONE
```

`HBONE` means enrolled: ztunnel carries these workloads in its mutual TLS tunnel. There is no waypoint yet, so nothing in the path can read HTTP.

---

## Step 3: Add the Waypoint

Create the waypoint, enroll the namespace, wait for it, and check the `Gateway`:

```sh
istioctl waypoint apply -n ambient-shop --enroll-namespace
kubectl -n ambient-shop rollout status deployment waypoint --timeout=180s
kubectl -n ambient-shop get gateway waypoint \
  -o custom-columns='NAME:.metadata.name,CLASS:.spec.gatewayClassName,PROGRAMMED:.status.conditions[?(@.type=="Programmed")].status'
```

```text
✓ waypoint ambient-shop/waypoint applied
✓ namespace ambient-shop labeled with "istio.io/use-waypoint: waypoint"

NAME       CLASS            PROGRAMMED
waypoint   istio-waypoint   True
```

Two separate things happened. `waypoint apply` created the `Gateway`, and Istio turned it into a running Envoy. `--enroll-namespace` labelled the namespace `istio.io/use-waypoint`, which makes ztunnel route through the waypoint.

Check that ztunnel now routes the Service through it:

```sh
istioctl ztunnel-config service | grep ambient-shop
```

On the `catalog-api` row, the `WAYPOINT` column names `waypoint`. Use the service view for this: the workload view's `WAYPOINT` column stays `None` for a waypoint that serves a Service.

Note that the waypoint pod runs in `ambient-shop` too. That is why the grader leaves it out when it compares pod UIDs with the baseline. Adding a waypoint adds a pod; it does not recreate yours.

---

## Step 4: The HTTPRoute

Save this as `catalog-header.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: catalog-header
  namespace: ambient-shop
spec:
  parentRefs:
    - group: ""
      kind: Service
      name: catalog-api
  rules:
    - filters:
        - type: ResponseHeaderModifier
          responseHeaderModifier:
            set:
              - name: x-served-via
                value: waypoint
      backendRefs:
        - name: catalog-api
          port: 80
```

Apply it:

```sh
kubectl apply -f catalog-header.yaml
```

`parentRefs` points at the **Service**, not a `Gateway`. That is the Gateway API's mesh pattern: the route describes what happens to traffic headed for that Service, wherever it comes from.

---

## Step 5: The Layer 7 AuthorizationPolicy

An `AuthorizationPolicy` is the guard's list at the airlock: who may come aboard and what they may do.

Save this as `catalog-methods.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: catalog-methods
  namespace: ambient-shop
spec:
  targetRefs:
    - group: ""
      kind: Service
      name: catalog-api
  action: ALLOW
  rules:
    - to:
        - operation:
            methods: ["GET"]
```

Apply it:

```sh
kubectl apply -f catalog-methods.yaml
```

Notice two things.

`action: ALLOW` with a single rule works as a guest list. Once any `ALLOW` policy applies to a workload, anything its rules do not match is denied. So allowing `GET` denies everything else, and you do not need a separate `DENY` policy.

`targetRefs` pointing at the **Service** binds the policy to the waypoint that handles that Service. (`selector` on workload labels also exists and binds to the workload itself. For a layer 7 rule enforced by a waypoint, `targetRefs` is the documented form.)

---

## Step 6: Prove Both Outcomes

Send a `GET` from `storefront` and read the response headers:

```sh
kubectl -n ambient-shop exec deploy/storefront -c storefront -- \
  curl -s -i -X GET http://catalog-api/ | head -6
```

```text
HTTP/1.1 200 OK
server: istio-envoy
date: ...
content-type: text/html
content-length: 615
x-served-via: waypoint
```

Then try a `DELETE` from `storefront`, and a `GET` from `batch-runner`:

```sh
kubectl -n ambient-shop exec deploy/storefront -c storefront -- \
  curl -s -o /dev/null -w 'DELETE -> %{http_code}\n' -X DELETE http://catalog-api/
kubectl -n ambient-shop exec deploy/batch-runner -c batch-runner -- \
  curl -s -o /dev/null -w 'GET -> %{http_code}\n' http://catalog-api/
```

```text
DELETE -> 403
GET -> 200
```

`x-served-via: waypoint` and `server: istio-envoy` prove that an HTTP-aware proxy is in the path. `DELETE -> 403` proves that it enforces a rule on the method, something ztunnel cannot do.

If the `DELETE` still returns `200` right after you applied the policy, wait a few seconds and try again. The waypoint receives its configuration from `istiod` over xDS, and that takes a moment.

---

## Step 7: Submit

Send the lab for grading:

```sh
astrona submit
```

The grader checks:

- the ambient label, and that `istio-injection` is absent;
- that the application pods' UIDs match the baseline, and that no pod has a sidecar;
- the waypoint's class, `Programmed` status, readiness, and namespace enrollment;
- that ztunnel's service view routes `catalog-api` through the waypoint;
- that the `HTTPRoute` attaches to the Service, and that the policy exists;
- **live requests** from `storefront`: the `x-served-via` header, `GET` returning 200, and `DELETE` returning 403.

---

## Optional: See What Happens Without the Waypoint

This is not graded, and it is the most useful thing to see in this section. Do it only after you have submitted, or rebuild the waypoint afterwards. Delete the waypoint and send the `DELETE` again:

```sh
istioctl waypoint delete waypoint -n ambient-shop
sleep 10
kubectl -n ambient-shop exec deploy/storefront -c storefront -- \
  curl -s -o /dev/null -w 'DELETE -> %{http_code}\n' -X DELETE http://catalog-api/
kubectl -n ambient-shop get authorizationpolicy catalog-methods
```

```text
DELETE -> 200

NAME              AGE
catalog-methods   4m
```

The policy is still there and still looks healthy, but the restriction is gone. Traffic is still encrypted and still checked, because that is ztunnel's job, and ztunnel is untouched. The mesh did not break; it got smaller, silently.

That is the security lesson to take from this section: **a missing waypoint looks exactly like a quiet one.**

Build it again if you want the lab to pass:

```sh
istioctl waypoint apply -n ambient-shop --enroll-namespace
kubectl -n ambient-shop rollout status deployment waypoint --timeout=180s
```

---

## Common Mistakes

*   **Running `kubectl rollout restart` after labelling.** The namespace ends up enrolled, but the pod UIDs change, which fails the check. Ambient enrollment needs no restart.
*   **Writing the method rule and skipping the waypoint.** The policy is accepted, healthy, and does nothing. `DELETE` returns 200, and nothing says why.
*   **Leaving out `--enroll-namespace`.** The waypoint runs, ztunnel does not route through it, and both layer 7 requirements fail together.
*   **Adding a separate `DENY` policy for the other methods.** An `ALLOW` policy already denies anything its rules do not match. Two policies here usually means an interaction you did not intend.
*   **Pointing `parentRefs` at a `Gateway`.** In the mesh, the route attaches to the Service.
*   **Deleting `lab-baseline` while tidying up.** It is the grader's record of what was running before you started.
*   **Testing `DELETE` right after applying the policy.** The waypoint receives configuration over xDS; give it a few seconds. The grader retries for the same reason.
