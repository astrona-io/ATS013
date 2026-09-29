# Solution Walkthrough

Follow these steps to add a waypoint and prove L7 processing is really in the path.

---

## Step 1: See the Gap First

Write the route and apply it **before** creating the waypoint. It is worth watching the failure, because it is silent.

```sh
cat > notification-header.yaml <<'YAML'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: notification-header
  namespace: ambient-l7
spec:
  parentRefs:
    - group: ""
      kind: Service
      name: notification-service
  rules:
    - filters:
        - type: ResponseHeaderModifier
          responseHeaderModifier:
            set:
              - name: x-processed-by
                value: waypoint
      backendRefs:
        - name: notification-service
          port: 80
YAML

kubectl apply -f notification-header.yaml
kubectl -n ambient-l7 get httproute notification-header \
  -o jsonpath='{.status.parents[0].conditions[*].type}{"\n"}'
kubectl -n ambient-l7 exec deploy/tester -- curl -s -i http://notification-service/ | head -3
```

```text
httproute.gateway.networking.k8s.io/notification-header created
Accepted ResolvedRefs

HTTP/1.1 200 OK
Server: nginx/1.27.4
Date: ...
```

The route exists, its status says `Accepted` and `ResolvedRefs`, the request succeeds — and there is **no** `x-processed-by` header. `Server: nginx/1.27.4` means the response came straight from the application, through no HTTP-aware proxy.

Read the `parentRefs` block while you are here. In ingress use an `HTTPRoute` attaches to a `Gateway`; here it attaches to a **Service** (`kind: Service`, empty `group` meaning core Kubernetes). That is the Gateway API's mesh pattern — the route describes what happens to traffic destined for that Service, wherever it comes from.

---

## Step 2: Create the Waypoint

```sh
istioctl waypoint apply -n ambient-l7 --enroll-namespace
kubectl -n ambient-l7 rollout status deployment waypoint --timeout=180s
```

```text
✓ waypoint ambient-l7/waypoint applied
✓ namespace ambient-l7 labeled with "istio.io/use-waypoint: waypoint"
deployment "waypoint" successfully rolled out
```

Two things happened, and they are separate:

*   `waypoint apply` created a `Gateway` resource, which Istio turned into a running Envoy Deployment.
*   `--enroll-namespace` labelled the namespace `istio.io/use-waypoint: waypoint`, which is what tells ztunnel to route the namespace's traffic through it.

Without the second, you get a healthy, idle proxy and no change in behaviour.

```sh
kubectl -n ambient-l7 get gateway waypoint \
  -o custom-columns='NAME:.metadata.name,CLASS:.spec.gatewayClassName,PROGRAMMED:.status.conditions[?(@.type=="Programmed")].status'
kubectl get ns ambient-l7 --show-labels
```

```text
NAME       CLASS            PROGRAMMED
waypoint   istio-waypoint   True

NAME         STATUS   AGE   LABELS
ambient-l7   Active   12m   istio.io/dataplane-mode=ambient,istio.io/use-waypoint=waypoint,...
```

`gatewayClassName: istio-waypoint` is the single field that makes this a waypoint rather than an ingress gateway — same API, same proxy binary, completely different role. The namespace now carries two labels doing two jobs: `dataplane-mode` puts it in the mesh at L4, `use-waypoint` routes its traffic through L7.

---

## Step 3: Confirm ztunnel Knows Where to Send Traffic

```sh
istioctl ztunnel-config workload | grep ambient-l7
```

```text
NAMESPACE   POD NAME                      ADDRESS      NODE                     WAYPOINT  PROTOCOL
ambient-l7  notification-service-...      10.244.0.14  astro-...-control-plane  waypoint  HBONE
ambient-l7  tester-...                    10.244.0.15  astro-...-control-plane  waypoint  HBONE
ambient-l7  waypoint-5f6d8c9b74-h2vzq     10.244.0.16  astro-...-control-plane  None      HBONE
```

The `WAYPOINT` column read `None` before enrollment and now names `waypoint`. The waypoint pod itself reads `None` — a waypoint does not route through itself, which would be a loop.

The path a request now takes:

```text
   tester  ──►  ztunnel (tester's node)
                   │  destination has a waypoint? yes
                   ▼
              waypoint (Envoy)  ── terminates HBONE, parses HTTP,
                   │                applies the HTTPRoute
                   ▼
              ztunnel (destination node)  ──►  notification-service
```

Neither application pod was modified. Both legs are HBONE, so mTLS is preserved end to end; the waypoint terminates one tunnel and opens another.

---

## Step 4: The Same Request, Through L7

The `HTTPRoute` is still exactly as you applied it in Step 1. Nothing about it needed fixing — it was correct and had no executor.

```sh
kubectl -n ambient-l7 exec deploy/tester -- curl -s -i http://notification-service/ | head -7
```

```text
HTTP/1.1 200 OK
server: istio-envoy
date: ...
content-type: text/html
content-length: 615
x-envoy-upstream-service-time: 2
x-processed-by: waypoint
```

Three tells that Envoy is now in the path: `x-processed-by: waypoint` (a header no application set), `server: istio-envoy` instead of `nginx/1.27.4`, and `x-envoy-upstream-service-time` timing the upstream call.

You can also look at the route from inside the waypoint's Envoy, using the ordinary sidecar tooling:

```sh
WP=$(kubectl -n ambient-l7 get pod -l gateway.networking.k8s.io/gateway-name=waypoint \
  -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config route "$WP.ambient-l7" | head -5
```

Seeing your route's name in the output is the strongest evidence the configuration reached the proxy, as opposed to merely existing in the cluster.

---

## Step 5: Submit

```sh
astrona submit
```

The grader checks that the namespace is still ambient, that the `waypoint` Gateway is class `istio-waypoint` and `Programmed: True` with a ready Deployment, that the namespace carries `istio.io/use-waypoint`, that ztunnel's `WAYPOINT` column names it, that the `HTTPRoute` attaches to `Service/notification-service` and is `Accepted` — and then runs a **real request** from `tester` and requires the `x-processed-by: waypoint` header. That last check is the only one that proves anything is parsing HTTP.

---

## Optional: Watch It Degrade

Delete the waypoint and try the request again:

```sh
istioctl waypoint delete waypoint -n ambient-l7
kubectl -n ambient-l7 exec deploy/tester -- curl -s -i http://notification-service/ | head -2
```

```text
HTTP/1.1 200 OK
Server: nginx/1.27.4
```

Traffic still flows, still encrypted, still authenticated — the mesh did not break, it got smaller. L7 rules silently stopped applying. If an `AuthorizationPolicy` had been enforcing an HTTP-level restriction, that restriction would now be gone while the policy object still looked healthy.

Recreate it before submitting: `istioctl waypoint apply -n ambient-l7 --enroll-namespace`.

---

## Common Mistakes

*   **Applying the `HTTPRoute` and stopping.** Accepted, statused, inert. Check `istioctl ztunnel-config workload` for a non-`None` `WAYPOINT` before debugging the route.
*   **Omitting `--enroll-namespace`.** The proxy runs and receives no traffic; `WAYPOINT` stays `None`.
*   **Pointing `parentRefs` at a `Gateway`.** In a mesh the route attaches to the **Service**. The grader checks `kind` and `name`.
*   **Reading route status as proof of effect.** `Accepted` means well-formed and bound, not enforced. Only a real request proves L7 is in the path.
*   **Naming the waypoint something else.** The task asks for `waypoint`, which is also `istioctl waypoint apply`'s default name.
*   **Removing the ambient label.** A waypoint adds L7 on top of the L4 mesh; without `dataplane-mode=ambient`, ztunnel never captures the connection in the first place.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [Ambient mode overview](https://istio.io/v1.30/docs/ambient/overview/) — what ambient replaces and what it keeps
- [ztunnel architecture](https://istio.io/v1.30/docs/ambient/architecture/data-plane/) — the node proxy and what it does and does not do
- [Waypoint proxies](https://istio.io/v1.30/docs/ambient/usage/waypoint/) — where L7 policy runs in ambient
- [HBONE](https://istio.io/v1.30/docs/ambient/architecture/hbone/) — the tunnel ambient uses between nodes
- [Istio annotations and labels](https://istio.io/v1.30/docs/reference/config/annotations/) — the reference list of both
- [Diagnostic tools](https://istio.io/v1.30/docs/ops/diagnostic-tools/proxy-cmd/) — `proxy-status` and `proxy-config` in full
- [istioctl command reference](https://istio.io/v1.30/docs/reference/commands/istioctl/) — every subcommand and flag
