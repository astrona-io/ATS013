# L7 Configuration Through A Waypoint

Your playground now has a waypoint running in `ambient-l7`, with the namespace enrolled to it. The `HTTPRoute` named `notification-header`, which sets the response header `x-processed-by: waypoint`, is still applied and unchanged. It was correct all along; it just had nothing to carry it out. In this part you watch it take effect, and you learn to prove that the configuration really reached the proxy.

## The same route, now that something can run it

Nothing about the route changes in this step. The only difference from before is that a waypoint, the checkpoint station that reads the signal's contents, now sits in the path.

<!-- astrona:playground:renew -->

### See it in your playground

Send the same request from `tester` again:

```sh
kubectl -n ambient-l7 exec deploy/tester -- curl -s -i http://notification-service/ | head -7
```

Expect something like:

```text
HTTP/1.1 200 OK
server: istio-envoy
date: Sat, 27 Sep 2026 09:48:11 GMT
content-type: text/html
content-length: 615
x-envoy-upstream-service-time: 2
x-processed-by: waypoint
```

Three signs show that the waypoint's Envoy is in the path:

- `x-processed-by: waypoint` is a header no application set. An HTTP-aware proxy added it.
- `server: istio-envoy` replaced `nginx/1.27.4`, so the response passed through Envoy on its way back. Without the waypoint, the same request showed `Server: nginx/1.27.4`.
- `x-envoy-upstream-service-time` is Envoy timing the call to the application.

### A habit for debugging

That before-and-after is worth turning into a habit. When layer 7 configuration in an ambient namespace seems to do nothing, do not start with "is my route correct?". Start with "is there a waypoint, and is this traffic routed through it?".

> [!TIP]
> When an `HTTPRoute` or a layer 7 policy in an ambient namespace seems to do nothing, check for the waypoint first: `istioctl waypoint list -n <namespace>`, then the `WAYPOINT` column in `istioctl ztunnel-config service`. Only then debug the route itself.

## Reading the route's status honestly

The `HTTPRoute` reported `Accepted` and `ResolvedRefs` before the waypoint existed, and it reports the same now. That is not a bug in the status. The status answers a narrower question than most people assume.

### What the conditions mean

Each condition on the route proves one thing, and only that thing:

| Condition | Means | Does **not** mean |
| --- | --- | --- |
| `Accepted` | The route is well formed and bound to the parent named in `parentRefs` | Anything is carrying it out |
| `ResolvedRefs` | Every `backendRefs` target exists and can be referenced | Traffic is reaching that backend |

So route status is a check on the object, not on what it does. The real check is the response (a header, a status code, a timing header), or the routes the waypoint's Envoy actually received.

### See it in your playground

The waypoint is an ordinary Envoy, so the ordinary `istioctl proxy-config` commands work on it. `istioctl proxy-config route` lists the routes a proxy holds. Find the waypoint pod's name, then read its routes:

```sh
WAYPOINT_POD=$(kubectl -n ambient-l7 get pod -l gateway.networking.k8s.io/gateway-name=waypoint -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config route "$WAYPOINT_POD.ambient-l7" | head -10
```

Expect something like:

```text
NAME                                          VHOST NAME                              DOMAINS     MATCH     VIRTUAL SERVICE
inbound-vip|80|http|notification-service...   inbound|http|80                         *           /*        notification-header.ambient-l7
```

Your route's name, `notification-header.ambient-l7`, appears in the `VIRTUAL SERVICE` column. That is the strongest proof that the configuration reached the proxy, and does not merely exist in the cluster. Use `proxy-config` only on the waypoint pod: the application pods in an ambient namespace have no Envoy of their own.

## Common pitfalls

> [!WARNING]
> **Debugging the route before checking for the waypoint.** An `HTTPRoute` in a namespace with no waypoint is accepted, gets a status, and does nothing. Check that a waypoint exists and that ztunnel names it first.
>
> **Reading route status as proof of effect.** `Accepted` means well formed and bound, not enforced. Only a real response, or the route inside the waypoint's Envoy, proves it works.
>
> **Running `istioctl proxy-config` on an application pod.** Ambient pods have no sidecar. Point it at the waypoint pod instead.
>
> **Expecting a waypoint to cover traffic from outside the mesh.** ztunnel only captures connections from meshed workloads. A client outside the mesh reaches the Service directly and skips the waypoint.

## Your mission: Waypoint Proxy For L7

You can now add a waypoint, attach an `HTTPRoute` to a Service, and prove that layer 7 processing is in the path. Now prove it in a graded mission: deploy a namespace waypoint, enroll the namespace to it, attach a header-setting route, and show a real request coming back with that header.

The mission runs in its own training solar system, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-013-playground-040-02
```

Then start the mission:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-040/module-02/labs/lab-01
```

Read the task in [`question.md`](./labs/lab-01/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/module-02/labs/lab-01
```

When the mission is done, remove it and wake your playground up again:

```sh
astrona destroy ats-013-lab-040-02
astrona start ats-013-playground-040-02
```
