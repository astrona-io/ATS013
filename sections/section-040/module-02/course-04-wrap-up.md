# Wrap-Up: Mission Debrief

Well flown, astronaut. You have finished every part and the mission in this module. Before you move on, look back at what you learned, check yourself, and land the playground cleanly.

## What you learned

This module added the checkpoint station: a waypoint proxy that reads the signal's contents where the relay towers cannot.

**From [What A Waypoint Is And How Traffic Reaches It](./course-01-what-a-waypoint-is.md):**

- An `HTTPRoute` in an ambient namespace with no waypoint is accepted, reports `Accepted` and `ResolvedRefs`, and does nothing.
- In the mesh, an `HTTPRoute` attaches to a **Service** through `parentRefs` with `kind: Service`, not to a `Gateway`.
- A waypoint is a Gateway API `Gateway` with `gatewayClassName: istio-waypoint`. `istioctl waypoint apply` creates it; `--enroll-namespace` adds the `istio.io/use-waypoint` label that sends traffic to it.
- ztunnel decides to send traffic through the waypoint. Both legs stay HBONE, so mutual TLS is kept end to end. `istioctl ztunnel-config service` shows which waypoint a Service uses.
- Without the Gateway API CRDs, `istioctl waypoint apply` fails with `no matches for kind "Gateway"`.

**From [L7 Configuration Through A Waypoint](./course-02-l7-configuration-through-a-waypoint.md):**

- With the waypoint in place, the same route takes effect: the response carries `x-processed-by: waypoint` and `server: istio-envoy`.
- Route status checks the object, not its effect. The real proof is the response, or the route inside the waypoint's Envoy (`istioctl proxy-config route` on the waypoint pod).

**From [Scoping And Removing Waypoints](./course-03-scoping-and-removing-waypoints.md):**

- A service waypoint (`--for service`) is attached by labelling a Service `istio.io/use-waypoint`. The Service label beats the namespace label.
- Deleting a waypoint drops the mesh to layer 4: mutual TLS, identity and layer 4 policy stay, while HTTP routing and layer 7 policy silently stop.
- A waypoint is a Deployment you own, size and watch; `istioctl waypoint status` is the first check when layer 7 stops working.

## Your missions

You proved the skill in a graded mission, right after the part that taught it:

| Mission | After the part | What you proved |
| --- | --- | --- |
| [Waypoint Proxy For L7](./labs/lab-01/question.md) | L7 Configuration Through A Waypoint | add a namespace waypoint and a header route, and prove layer 7 processing with a real request |

If you skipped it, go back to it now. It is short.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. You apply an <code>HTTPRoute</code> in an ambient namespace with no waypoint. Its status says <code>Accepted</code>. Does it work?</summary>

No. `Accepted` only means the route is well formed and bound to its parent. ztunnel cannot read HTTP, so nothing carries the route out until a waypoint is in the path.
</details>

<details>
<summary>2. Which field turns a Gateway API <code>Gateway</code> into a waypoint?</summary>

`gatewayClassName: istio-waypoint`. An ingress gateway uses the class `istio`.
</details>

<details>
<summary>3. You run <code>istioctl waypoint apply -n shop</code> without <code>--enroll-namespace</code>. The waypoint is <code>Programmed: True</code>, but nothing changes. Why?</summary>

Creating the proxy and sending traffic to it are separate steps. Without the `istio.io/use-waypoint` label on the namespace or a Service, ztunnel never routes through the waypoint, so it sits idle.
</details>

<details>
<summary>4. Which component decides to send a signal through the waypoint?</summary>

ztunnel. `istiod` tells it which destinations have a waypoint, and ztunnel then connects to the waypoint over HBONE instead of to the destination pod. Neither application pod changes.
</details>

<details>
<summary>5. <code>istioctl waypoint apply</code> fails with <code>no matches for kind "Gateway"</code>. What is wrong?</summary>

The Gateway API CRDs are not installed. Istio does not ship them, and a waypoint is a `Gateway`, so they must be installed first.
</details>

<details>
<summary>6. How can you prove that your route reached the waypoint's proxy?</summary>

Send a real request and look for the header the route sets, or run `istioctl proxy-config route` against the waypoint pod and find your route's name in the `VIRTUAL SERVICE` column.
</details>

<details>
<summary>7. When is a service waypoint a better choice than a namespace waypoint?</summary>

When only one Service needs layer 7, so the rest of the namespace avoids the extra hop, or when one busy Service needs its own proxy, sized on its own.
</details>

<details>
<summary>8. Someone deletes the waypoint in a namespace with a method-based <code>AuthorizationPolicy</code>. What happens?</summary>

Traffic keeps flowing with mutual TLS and layer 4 policy, but the method rule silently stops being enforced. The policy object still looks healthy.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and the mission if it is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-013-playground-040-02
```

If `astrona list` also showed the mission, remove it the same way:

```sh
astrona destroy ats-013-lab-040-02
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.
