# L7 Configuration Through A Waypoint

A waypoint that runs is not yet proof that your layer 7 (L7, HTTP-aware) configuration works. You need to see the configuration take effect on a real request, and you need to know which checks prove it and which only look like proof. This part sends the same request through the waypoint, reads what the route's status really says, and finds the route inside the waypoint's Envoy proxy.

The commands below need two things in the `ambient-l7` namespace. The first is the `notification-header` `HTTPRoute`, which attaches to the `notification-service` Service and sets the response header `x-processed-by: waypoint`. The second is a waypoint named `waypoint`, created and enrolled with `istioctl waypoint apply -n ambient-l7 --enroll-namespace`. If your playground is fresh, create both before you go on.

## The same route, now with a proxy to run it

Nothing about the route changes in this step. The route was correct all along; it only had no proxy to carry it out. The one difference now is that a waypoint, an Envoy proxy that reads HTTP (Hypertext Transfer Protocol) requests, sits in the path between `tester` and `notification-service`.

Send the same request from `tester` again:

<!-- astrona:playground:renew -->

```sh
kubectl -n ambient-l7 exec deploy/tester -- curl -s -i http://notification-service/ | head -7
```

The output looks like this:

```text
HTTP/1.1 200 OK
server: istio-envoy
date: Sat, 27 Sep 2026 09:48:11 GMT
content-type: text/html
content-length: 615
x-envoy-upstream-service-time: 2
x-processed-by: waypoint
```

Three signs in this response show that the waypoint's Envoy handled it:

- `x-processed-by: waypoint` is a header that nginx does not set. The waypoint added it, because the `HTTPRoute` told it to.
- `server: istio-envoy` replaced `nginx/1.27.4`, so the response passed through Envoy on its way back. Without the waypoint, the same request showed `Server: nginx/1.27.4`.
- `x-envoy-upstream-service-time` is the time, in milliseconds, that Envoy measured for the call to nginx.

That before-and-after comparison is worth turning into a habit. When layer 7 configuration in an ambient namespace seems to do nothing, do not start with "is my route correct?". Start with "is there a waypoint, and does ztunnel send this traffic through it?". ztunnel is the per-node proxy of ambient mode; it decides, per destination, whether a connection goes through a waypoint.

> [!TIP]
> When an `HTTPRoute` or a layer 7 policy in an ambient namespace seems to do nothing, check for the waypoint first: `istioctl waypoint list -n <namespace>`, then the `WAYPOINT` column in `istioctl ztunnel-config service`. Only then debug the route itself.

## What the route's status proves

The response proved that the route works, so it is fair to ask what the route's status proved. The `HTTPRoute` reported `Accepted` and `ResolvedRefs` before the waypoint existed, and it reports the same now. That is not a bug in the status. The status answers a narrower question than most people assume.

Each condition on the route proves one thing, and only that thing:

| Condition | Means | Does **not** mean |
| --- | --- | --- |
| `Accepted` | The route is well formed and bound to the parent named in `parentRefs` | A proxy is carrying it out |
| `ResolvedRefs` | Every `backendRefs` target exists and can be referenced | Traffic is reaching that backend |

So the route's status is a check on the object, not on what it does. The real check is the response (a header, a status code, a timing header), or the routes the waypoint's Envoy actually received.

## The route inside the waypoint's Envoy

The waypoint is an ordinary Envoy, so the ordinary `istioctl proxy-config` commands work on it. `istioctl proxy-config route` lists the routes one proxy holds, as the proxy received them from `istiod`. Store the waypoint pod's name in a variable, then read its routes:

```sh
WAYPOINT_POD=$(kubectl -n ambient-l7 get pod -l gateway.networking.k8s.io/gateway-name=waypoint -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config route "$WAYPOINT_POD.ambient-l7" | head -10
```

The output looks like this (shortened):

```text
NAME                                          VHOST NAME                              DOMAINS     MATCH     VIRTUAL SERVICE
inbound-vip|80|http|notification-service...   inbound|http|80                         *           /*        notification-header.ambient-l7
```

The route's name, `notification-header.ambient-l7`, appears in the `VIRTUAL SERVICE` column, even though it came from an `HTTPRoute`. That is the strongest proof that the configuration reached the proxy, and does not only exist in the cluster. Run `proxy-config` only on the waypoint pod: the application pods in an ambient namespace have no Envoy of their own.

You now know how to prove that a waypoint carries out a route: a real response with the header and `server: istio-envoy`, and the route's name in the waypoint's own route table. You also know that `Accepted` and `ResolvedRefs` only check the object. The open question is scope: whether every Service in the namespace should pay for the extra hop, and what happens when a waypoint goes away.

## Common pitfalls

> [!WARNING]
> **Debugging the route before checking for the waypoint.** An `HTTPRoute` in a namespace with no waypoint is accepted, gets a status, and does nothing. First check that a waypoint exists and that ztunnel names it.
>
> **Reading route status as proof of effect.** `Accepted` means well formed and bound, not enforced. Only a real response, or the route inside the waypoint's Envoy, proves it works.
>
> **Running `istioctl proxy-config` on an application pod.** Ambient pods have no sidecar proxy. Point the command at the waypoint pod instead.
>
> **Expecting a waypoint to cover traffic from outside the mesh.** ztunnel only captures connections from meshed workloads. A client outside the mesh reaches the Service directly and skips the waypoint.

## Your mission: Waypoint Proxy For L7

You can now add a waypoint, attach an `HTTPRoute` to a Service, and prove that layer 7 processing is in the path. The lab asks you to deploy a namespace waypoint, enroll the namespace to it, attach a route that sets a response header, and show a real request coming back with that header.

The lab runs on its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-013-playground-040-02
```

Then start the lab. The task is on the next page; solve it on your own first:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-040/module-02/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-013-lab-040-02
astrona start ats-013-playground-040-02
```
