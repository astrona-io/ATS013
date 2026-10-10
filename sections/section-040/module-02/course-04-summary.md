# Summary

In ambient mode, ztunnel handles layer 4 for every workload: mutual TLS, workload identity and policy on identities and ports. It does not read HTTP. An `HTTPRoute` in an ambient namespace with no waypoint is accepted by the API server, reports `Accepted` and `ResolvedRefs`, and does nothing. In the mesh, an `HTTPRoute` attaches to a Service through `parentRefs` with `kind: Service`, not to a `Gateway`.

A waypoint is an Envoy proxy that Istio creates from a Gateway API `Gateway` with `gatewayClassName: istio-waypoint`. `istioctl waypoint apply` writes that `Gateway`, and `--enroll-namespace` adds the `istio.io/use-waypoint` label that sends traffic to it. Creating the waypoint and enrolling to it are separate steps; a waypoint with nothing enrolled runs and receives no requests. Istio does not ship the Gateway API CRDs, so without them `istioctl waypoint apply` fails with `no matches for kind "Gateway"`.

ztunnel, not the application, sends traffic through the waypoint. `istiod` tells ztunnel which destinations have a waypoint, and ztunnel then connects to the waypoint over HBONE instead of to the destination pod. The waypoint reads the request, applies the route and any layer 7 policy, and opens a new HBONE tunnel to the destination, so mutual TLS stays in place end to end. `istioctl ztunnel-config service` shows which waypoint each Service uses; the workload view shows `None` for a waypoint that serves a Service.

The route's status checks the object, not its effect. The proof that a waypoint carries out a route is a real response: the header the route sets, `server: istio-envoy` and `x-envoy-upstream-service-time`. The route's name in `istioctl proxy-config route` for the waypoint pod proves that the configuration reached the proxy. Application pods in an ambient namespace have no Envoy of their own, so `proxy-config` only works on the waypoint.

A service waypoint, created with `--for service`, serves only the Services that carry the `istio.io/use-waypoint` label, and the Service label beats the namespace label. Scoping a waypoint to the Services that need layer 7 saves the extra hop for the rest. Deleting a waypoint reduces the mesh to layer 4: mutual TLS, identity and layer 4 policy remain, while HTTP routing, header changes and layer 7 authorization rules stop with no error.

Key facts to remember:

- The `istio.io/dataplane-mode=ambient` label puts a namespace in the mesh; the `istio.io/use-waypoint` label sends its traffic through a waypoint.
- A waypoint is a Deployment you own: size it, scale it and check it with `istioctl waypoint status`.
- New ambient layer 7 configuration uses the Gateway API (`HTTPRoute`); do not mix it with `VirtualService` for the same Service.

<!-- astrona:playground:destroy -->
