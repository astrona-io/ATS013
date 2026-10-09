# Section 040 Knowledge Check: Installing Istio In Sidecar Or Ambient Mode

Test your understanding of the ambient data plane, what enrollment changes and what it does not, and the boundary between what ztunnel enforces and what needs a waypoint proxy.

Two short forms appear throughout: **L4** means layer 4, the transport layer (who is talking, on which port), and **L7** means layer 7, the application layer (HTTP methods, paths and headers). **mTLS** means mutual TLS: both sides prove their identity with a certificate before they talk.

---

## Scenario-Based Questions

### Question 1
Which components does the `ambient` profile add that the `default` profile does not?
*   **A)** A second `istiod` and a waypoint proxy.
*   **B)** The `istio-cni-node` and `ztunnel` DaemonSets.
*   **C)** The Gateway API CRDs and a `GatewayClass`.
*   **D)** A `ztunnel` Deployment and an egress gateway.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `istiod` is the same control plane in both modes. Ambient adds two DaemonSets: `istio-cni-node`, which programs the traffic redirection at the node level, and `ztunnel`, the per-node L4 proxy. DaemonSet is the load-bearing word — sidecar mode scales proxies with the number of *pods*, ambient mode with the number of *nodes*.
*   **Why others are incorrect:**
    *   *Option A* invents a second control plane, and waypoints are opt-in per namespace or service, never installed by the profile.
    *   *Option C* is a real prerequisite for waypoints but Istio does not ship the Gateway API CRDs — you install them separately.
    *   *Option D* gets the workload kind wrong; ztunnel is a DaemonSet, and the ambient profile installs no gateways.
</details>

---

### Question 2
You label a namespace `istio.io/dataplane-mode=ambient`. Its running pods are not restarted. Are they in the mesh?
*   **A)** No — like sidecar injection, enrollment applies only to pods created afterwards.
*   **B)** Yes. Enrollment changes node-level redirection and ztunnel's configuration, both outside the pod, so nothing has to be recreated.
*   **C)** Only pods that are restarted within the certificate rotation window.
*   **D)** Yes, but only for outbound traffic until the pods restart.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** This is the headline difference from sidecar mode, and it follows from the mechanism. Sidecar injection is a *mutation of the pod spec*, so it can only happen at admission. Ambient enrollment changes things that live outside the pod — the redirection `istio-cni-node` programs, and the workload state `istiod` pushes to ztunnel. The pod does not need to know and does not change. The observable proof is that `AGE` keeps counting and `RESTARTS` stays at 0.
*   **Why others are incorrect:**
    *   *Option A* applies the sidecar rule to a mechanism it does not describe.
    *   *Option C* and *Option D* invent partial states that do not exist.
</details>

---

### Question 3
A colleague runs `kubectl get pods -n ambient-demo`, sees one container per pod, and concludes the mesh is broken. What should you tell them?
*   **A)** They are right; enrollment failed and the namespace needs relabelling.
*   **B)** In ambient mode a meshed pod is never modified, so container count cannot answer that question. Use `istioctl ztunnel-config workload` and read the `PROTOCOL` column.
*   **C)** The sidecar appears only after the first request.
*   **D)** They should look for an `istio-init` container instead.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Counting containers is the sidecar-mode habit, and in ambient mode it is not merely unhelpful — it actively misleads, because a fully meshed pod looks identical to an unmeshed one. `istioctl ztunnel-config workload` reports what ztunnel actually knows: `HBONE` means enrolled and reached over an mTLS tunnel, `TCP` means plain traffic.
*   **Why others are incorrect:**
    *   *Option A* accepts a wrong diagnosis.
    *   *Option C* invents lazy injection.
    *   *Option D* points at another sidecar-mode artifact that ambient pods also do not have.
</details>

---

### Question 4
What does `HBONE` refer to?
*   **A)** The health-check port every Istio proxy exposes.
*   **B)** HTTP-Based Overlay Network Environment — the mTLS-encrypted HTTP/2 tunnel ztunnels use to carry the original connection, on port 15008.
*   **C)** The Gateway API class name for waypoint proxies.
*   **D)** The protocol between `istiod` and each proxy for configuration.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** HBONE is ambient mode's transport. The application's connection is carried inside an authenticated, encrypted tunnel between ztunnels, so both ends have a cryptographic identity and the payload is encrypted — without the application knowing. Port 15008 appearing as the destination in a ztunnel access log, instead of the application's own port, is the visible sign of it.
*   **Why others are incorrect:**
    *   *Option A* describes port 15021.
    *   *Option C* describes `istio-waypoint`.
    *   *Option D* describes xDS, which is a different protocol on port 15012.
</details>

---

### Question 5
You apply an `AuthorizationPolicy` to an ambient namespace that denies requests unless the HTTP method is `GET`. There is no waypoint. What happens?
*   **A)** The policy is rejected, because L7 rules require a waypoint.
*   **B)** ztunnel enforces it — it can inspect HTTP headers to determine the method.
*   **C)** The policy is accepted, reports healthy, and has no effect. ztunnel is an L4 proxy and cannot read the method.
*   **D)** All traffic to the namespace is denied, because the rule cannot be evaluated.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

*   **Why C is correct:** This silent no-op is the single most common ambient-mode mistake. `AuthorizationPolicy` is one CRD, but a rule matching on `principals` or `ports` is L4 and enforceable by ztunnel, while a rule matching on methods, paths or headers is L7 and needs an HTTP-aware proxy in the path. Nothing errors, nothing warns, and the restriction you believe is in place is not.
*   **Why others are incorrect:**
    *   *Option A* assumes a validation step that does not exist.
    *   *Option B* misstates what a TCP-level proxy can do.
    *   *Option D* invents fail-closed behaviour.
</details>

---

### Question 6
`istioctl waypoint apply` fails with `no matches for kind "Gateway" in version "gateway.networking.k8s.io/v1"`. What is wrong?
*   **A)** The ambient profile was not installed.
*   **B)** The Gateway API CRDs are not installed. Istio does not ship them, and a waypoint is a `Gateway`.
*   **C)** The namespace is not enrolled in ambient mode.
*   **D)** `istioctl` is an older version than the control plane.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** The Gateway API is a separate Kubernetes SIG project with its own release cadence, and Istio does not bundle its CRDs. Since a waypoint *is* a `Gateway` of class `istio-waypoint`, the API server rejects the unknown kind. The error reads like an Istio bug and is not — the `ensure CRDs are installed first` clause is the diagnosis.
*   **Why others are incorrect:**
    *   *Option A* would produce a different failure, and `istiod` would be absent entirely.
    *   *Option C* would let the Gateway be created and simply route no traffic.
    *   *Option D* would not produce a missing-kind error.
</details>

---

### Question 7
You run `istioctl waypoint apply -n shop` without `--enroll-namespace`. The Gateway reports `Programmed: True` and the pod is running, but nothing changes. Why?
*   **A)** The waypoint needs a `VirtualService` before it takes traffic.
*   **B)** Creating the proxy and pointing traffic at it are separate steps — without `istio.io/use-waypoint` on the namespace or a Service, ztunnel never routes through it.
*   **C)** `Programmed: True` only means the Gateway was accepted, not that a pod exists.
*   **D)** Waypoints take effect only after the workloads are restarted.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `waypoint apply` writes the `Gateway`; `--enroll-namespace` adds the `istio.io/use-waypoint` label that tells ztunnel to send the namespace's traffic to it. Omit the second and you get a healthy, idle Envoy. The check is the `WAYPOINT` column of `istioctl ztunnel-config service`: no Service names the waypoint.
*   **Why others are incorrect:**
    *   *Option A* names the wrong resource and the wrong mechanism; ztunnel decides the routing, not a route resource.
    *   *Option C* misstates `Programmed`, which does mean a proxy was produced.
    *   *Option D* invents a restart requirement that ambient mode specifically does not have.
</details>

---

### Question 8
Someone deletes a waypoint in a namespace that relied on an L7 `AuthorizationPolicy`. What is the immediate effect?
*   **A)** Traffic to the namespace stops until the waypoint is recreated.
*   **B)** Traffic keeps flowing, still with mTLS and L4 policy — but the L7 rule silently stops being enforced, while the policy object still looks healthy.
*   **C)** ztunnel takes over enforcement of the L7 rule.
*   **D)** The `AuthorizationPolicy` is automatically deleted along with the waypoint.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Deleting a waypoint degrades the mesh to L4 rather than breaking it. Identity, mTLS and L4 authorization are ztunnel's job and are untouched. What is lost is HTTP routing, header manipulation, retries, timeouts and any authorization rule matching on HTTP — silently, in exactly the way those rules never applied before the waypoint existed. That is the security consequence worth remembering: a waypoint's absence is indistinguishable from its silence.
*   **Why others are incorrect:**
    *   *Option A* overstates it; the L4 mesh is unaffected.
    *   *Option C* is the assumption that makes this dangerous — ztunnel cannot read HTTP.
    *   *Option D* invents a garbage-collection relationship.
</details>

---

### Question 9
When is a **service** waypoint (`--for service`) a better choice than a namespace waypoint?
*   **A)** Always — namespace waypoints are deprecated.
*   **B)** When only one service in the namespace needs L7, or when one service needs its own independently-scaled proxy.
*   **C)** When the namespace contains more than one Service.
*   **D)** When the workloads are in sidecar mode rather than ambient mode.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** A waypoint is an extra hop, so it costs latency and a proxy to run. A namespace waypoint routes *all* the namespace's traffic through it, including traffic that only ever needed L4. Scoping to a Service avoids paying for that, and it also lets a high-throughput service have a dedicated, separately-sized proxy. Both are `Gateway` resources of class `istio-waypoint` — what differs is who is pointed at them, via a namespace label or Service labels.
*   **Why others are incorrect:**
    *   *Option A* is false; namespace waypoints are the common starting point.
    *   *Option C* is not by itself a reason — the question is which services need L7.
    *   *Option D* is backwards; waypoints are an ambient-mode construct.
</details>

---

## What comes next

The section capstone lab comes next. It combines the skills of the whole section in one task on a live cluster.
