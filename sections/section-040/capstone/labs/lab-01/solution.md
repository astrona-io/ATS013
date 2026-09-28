# Solution Walkthrough

Read this only after you have attempted the specification.

---

## Step 1: Sort the Requirements by Layer

The specification is really one question asked three times: **which layer enforces this?**

| Requirement | Enforced by | Needs a waypoint? |
| --- | --- | --- |
| Mesh identity, mTLS between workloads | ztunnel | No |
| A rule on source identity or port | ztunnel | No |
| Response header rewriting (`HTTPRoute`) | waypoint | **Yes** |
| A rule on the HTTP **method** | waypoint | **Yes** |

Requirements 6 and 7 are the exercise. `AuthorizationPolicy` is one CRD, but a rule matching on `methods` is L7 and a rule matching on `principals` or `ports` is L4. ztunnel enforces the second and cannot even see the first — it is a TCP-level proxy. Without a waypoint the policy applies cleanly, reports healthy, and does nothing.

---

## Step 2: Enroll, Without Recreating Anything

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

One label, no restart. `RESTARTS` is still 0 and `AGE` just kept counting.

The reason is mechanical and worth being able to state: sidecar injection mutates the **pod spec**, so it can only happen at admission. Ambient enrollment changes **node-level redirection** (via `istio-cni-node`) and **ztunnel's configuration** (via `istiod`) — both outside the pod.

```sh
istioctl ztunnel-config workload | grep ambient-shop
```

```text
NAMESPACE     POD NAME             ADDRESS      NODE     WAYPOINT  PROTOCOL
ambient-shop  batch-runner-...     10.244.0.12  ...      None      HBONE
ambient-shop  catalog-api-...      10.244.0.11  ...      None      HBONE
ambient-shop  storefront-...       10.244.0.13  ...      None      HBONE
```

`HBONE` means enrolled. `WAYPOINT None` means L4 only — nothing in the path can read HTTP yet.

---

## Step 3: Add the Waypoint

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

Two separate things: `waypoint apply` created the `Gateway` (and Istio turned it into a running Envoy), and `--enroll-namespace` labelled the namespace `istio.io/use-waypoint`, which is what makes ztunnel route through it.

Note the waypoint pod appears in `ambient-shop` — which is why the grader excludes it when comparing pod UIDs against the baseline. Adding a waypoint adds a pod; it does not recreate yours.

---

## Step 4: The HTTPRoute

```sh
cat > catalog-header.yaml <<'YAML'
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
YAML
kubectl apply -f catalog-header.yaml
```

`parentRefs` targets the **Service**, not a `Gateway`. That is the Gateway API's mesh pattern: the route describes what happens to traffic destined for that Service, wherever it originates.

---

## Step 5: The L7 AuthorizationPolicy

```sh
cat > catalog-methods.yaml <<'YAML'
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
YAML
kubectl apply -f catalog-methods.yaml
```

Two things to notice.

`action: ALLOW` with a single rule is **allow-list** semantics: once any ALLOW policy selects a workload, anything not matched by a rule is denied. So allowing `GET` denies everything else — you do not write a separate DENY.

`targetRefs` pointing at the **Service** is what binds the policy to the waypoint handling that Service. (`selector` on workload labels also exists and binds to the workload itself; for a waypoint-enforced L7 rule, `targetRefs` is the documented form.)

---

## Step 6: Prove Both Outcomes

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

`x-served-via: waypoint` and `server: istio-envoy` prove an HTTP-aware proxy is in the path. `DELETE -> 403` proves it is enforcing a rule on the method — something ztunnel structurally cannot do.

---

## Step 7: See What Happens Without the Waypoint

Not graded, and the single most instructive thing in the section. Delete the waypoint and re-run both requests:

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

The policy is still there, still looks healthy — and the restriction is gone. Traffic is still encrypted and still authenticated, because that is ztunnel's job and ztunnel is untouched. The mesh did not break; it got smaller, silently.

That is the security consequence worth carrying out of this section: **a waypoint's absence is indistinguishable from its silence.**

Recreate everything before submitting:

```sh
istioctl waypoint apply -n ambient-shop --enroll-namespace
kubectl -n ambient-shop rollout status deployment waypoint --timeout=180s
```

---

## Step 8: Submit

```sh
astrona submit
```

The grader checks the ambient label and the absence of `istio-injection`, compares the application pods' UIDs against the baseline, confirms no pod has a sidecar, checks the waypoint's class, `Programmed` status, readiness and namespace enrollment, checks ztunnel routes `catalog-api` through it, checks the `HTTPRoute` attaches to the Service and the policy exists — and then runs **live requests**: the `x-served-via` header, `GET` returning 200, and `DELETE` returning 403.

---

## Common Mistakes

*   **`kubectl rollout restart` after labelling.** The namespace ends up enrolled and the pod UIDs change, which fails the check. Ambient enrollment needs no restart.
*   **Writing the method rule and skipping the waypoint.** Accepted, healthy, and completely inert. `DELETE` returns 200 and nothing says why.
*   **Omitting `--enroll-namespace`.** The waypoint runs, `WAYPOINT` stays `None`, and both L7 requirements fail together.
*   **Adding a separate DENY policy for other methods.** An `ALLOW` policy already denies anything its rules do not match. Two policies here usually means an unintended interaction.
*   **Pointing `parentRefs` at a `Gateway`.** In a mesh the route attaches to the Service.
*   **Deleting `lab-baseline` while tidying.** It is the grader's record of what was running before you started.
*   **Testing `DELETE` immediately after applying the policy.** The waypoint receives configuration over xDS; give it a few seconds. The grader retries for the same reason.
