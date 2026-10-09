# Wrap-Up: Mission Debrief

Well flown, astronaut. You have finished every part and the mission in this module. Before you move on, look back at what you learned, check yourself, and land the playground cleanly.

## What you learned

This module took the communications officer off every ship. Shared relay towers, one per launch pad, now do the handshake for every ship docked there.

**From [The Ambient Data Plane](./course-01-the-ambient-data-plane.md):**

- The `ambient` profile installs `istiod` (the same control plane) plus two DaemonSets: `istio-cni-node` and `ztunnel`. Sidecar mode adds a proxy per pod; ambient mode adds one per node.
- `istio-cni-node` sets up rules in the pod's network space that send its traffic out to the ztunnel on the node. The pod itself is never changed.
- ztunnel carries traffic between nodes in HBONE: an HTTP/2 tunnel protected by mutual TLS, on port `15008`.
- The `ambient` profile installs no waypoint proxy and no Gateway API CRDs.

**From [Enrollment, Verification And The L4 Boundary](./course-02-enrollment-and-the-l4-boundary.md):**

- The label `istio.io/dataplane-mode=ambient` enrolls a namespace. No pod restarts, and removing the label takes the pods out again, also with no restart.
- A meshed ambient pod still has one container. Check membership with `istioctl ztunnel-config workload`: `HBONE` means enrolled, `TCP` means not.
- `istioctl ztunnel-config certificate` shows the identities ztunnel holds, and ztunnel's own log shows both sides' identities and port `15008` for each connection.
- ztunnel works at layer 4. Rules on methods, paths or headers need a waypoint; without one they are accepted and silently do nothing.

## Your missions

You proved the skill in a graded mission, right after the part that taught it:

| Mission | After the part | What you proved |
| --- | --- | --- |
| [Install Istio In Ambient Mode](./labs/lab-01/question.md) | Enrollment, Verification And The L4 Boundary | enroll a namespace with no pod recreated, and show ztunnel carries it over HBONE |

If you skipped it, go back to it now. It is short.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. Which components does the <code>ambient</code> profile add next to <code>istiod</code>, and what kind of workload are they?</summary>

`istio-cni-node` and `ztunnel`. Both are DaemonSets, so Kubernetes runs one pod of each on every node.
</details>

<details>
<summary>2. You label a namespace <code>istio.io/dataplane-mode=ambient</code>. Do you need to restart its pods?</summary>

No. Enrollment changes the node-level redirect (set up by `istio-cni-node`) and ztunnel's state (sent by `istiod`). Both live outside the pod, so the pods stay as they are and are in the mesh right away.
</details>

<details>
<summary>3. A colleague sees one container per pod in an ambient namespace and says the mesh is broken. How do you check?</summary>

Run `istioctl ztunnel-config workload` and read the `PROTOCOL` column. `HBONE` means the workload is enrolled. Container count says nothing in ambient mode, because a meshed pod is never changed.
</details>

<details>
<summary>4. In a ztunnel log line, the destination port is <code>15008</code>, but the app listens on port 80. Is something wrong?</summary>

No. Port `15008` is the HBONE port. ztunnel carries the connection in its mutual TLS tunnel to that port, and the application never sees it.
</details>

<details>
<summary>5. You apply an <code>AuthorizationPolicy</code> that matches on <code>methods: ["GET"]</code> in an ambient namespace with no waypoint. What happens?</summary>

The policy is accepted and looks healthy, but it has no effect. ztunnel works at layer 4 and cannot read the HTTP method. Only a waypoint proxy can enforce it.
</details>

<details>
<summary>6. What happens if a cluster's own network plugin does not allow chaining?</summary>

`istio-cni` cannot set up the redirect, so ambient mode does not work, and the pods may lose their network connection. Check the `istio-cni-node` logs first.
</details>

<details>
<summary>7. Can one namespace carry both <code>istio-injection=enabled</code> and <code>istio.io/dataplane-mode=ambient</code>?</summary>

It should not. The two labels choose different data planes. Pick one mode per namespace; a cluster can still run both modes in different namespaces.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and the mission if it is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-013-playground-040-01
```

If `astrona list` also showed the mission, remove it the same way:

```sh
astrona destroy ats-013-lab-040-01
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.
