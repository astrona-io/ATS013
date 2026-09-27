# Section 040: Installing Istio In Sidecar Or Ambient Mode

Everything in the previous sections put a proxy inside the pod. Ambient mode does not. The mesh moves down to the node, mutual TLS and L4 authorization happen there, and pod specs are never touched — so joining the mesh costs a label instead of a rolling restart of every workload.

That split is the section's real subject. ztunnel gives a whole cluster identity and encryption for one proxy per node; a waypoint proxy adds HTTP-aware behaviour, and you pay for Envoy only in the namespaces that need it. Knowing which layer owns a given capability is what stops you debugging an `HTTPRoute` that was correct all along and simply had nothing in the path able to execute it.

**Curriculum item covered:** Installing Istio in Sidecar or Ambient Mode

---

## What You Will Master

- The components the `ambient` profile adds — `istio-cni-node` and `ztunnel`, both DaemonSets — and what each is responsible for.
- Why ambient enrollment takes effect without recreating pods, and what that changes operationally.
- Enrolling and un-enrolling a namespace with `istio.io/dataplane-mode`.
- Checking mesh membership with `istioctl ztunnel-config workload` — and why counting containers cannot answer that question in ambient mode.
- HBONE, the mTLS transport between ztunnels, and reading workload identities out of ztunnel's own logs.
- The boundary: what ztunnel enforces at L4 on its own, and what needs a waypoint.
- What a waypoint proxy is, which object `istioctl waypoint apply` creates, and the field that makes it a waypoint rather than an ingress gateway.
- The path a request takes through a waypoint, applying a Gateway API `HTTPRoute`, and proving L7 processing from the response.
- Namespace waypoints versus service waypoints, and which behaviour survives if a waypoint is deleted.

---

## The Learning Path

### 1. Install Istio In Ambient Mode
*   **Module Reader:** **[Module 1: Install Istio In Ambient Mode](./module-01/course.md)**
    1. [The Ambient Data Plane](./module-01/course-01-the-ambient-data-plane.md)
    2. [Enrollment, Verification And The L4 Boundary](./module-01/course-02-enrollment-and-the-l4-boundary.md)
*   **Hands-on Playground:** `sections/section-040/module-01/playground` — Istio 1.30.5 with the `ambient` profile and an `ambient-demo` namespace that is not yet enrolled.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-040/module-01/playground
    ```
*   **Practice Lab Sandbox:** **`sections/section-040/module-01/labs/lab-01`**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-040/module-01/labs/lab-01
    ```
*   **Hands-on Objective:** Enroll a namespace into the ambient mesh without recreating a single pod — proved against the pod UIDs recorded before you started — and confirm membership through ztunnel rather than by counting containers.

### 2. Add A Waypoint Proxy For L7 In Ambient Mode
*   **Module Reader:** **[Module 2: Add A Waypoint Proxy For L7 In Ambient Mode](./module-02/course.md)**
    1. [What A Waypoint Is And How Traffic Reaches It](./module-02/course-01-what-a-waypoint-is.md)
    2. [L7 Configuration Through A Waypoint](./module-02/course-02-l7-configuration-through-a-waypoint.md)
*   **Hands-on Playground:** `sections/section-040/module-02/playground` — ambient Istio plus the Gateway API CRDs, and an already-enrolled `ambient-l7` namespace with no waypoint.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-040/module-02/playground
    ```
*   **Practice Lab Sandbox:** **`sections/section-040/module-02/labs/lab-01`**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-040/module-02/labs/lab-01
    ```
*   **Hands-on Objective:** Watch an HTTPRoute be accepted and do nothing, then add the waypoint that makes it work, and prove L7 processing is in the path with a real response header.

### 3. Section Capstone Challenge
*   **Comprehensive Challenge:** **`sections/section-040/capstone/labs/lab-01` (An Ambient Mesh With Selective L7)**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-040/capstone/labs/lab-01
    ```
*   **Hands-on Objective:** Enroll a namespace with no pod recreated, add a waypoint, and enforce an HTTP-method rule that ztunnel structurally cannot — proving both outcomes with live requests, 200 for GET and 403 for DELETE.

---

## Ready for Assessment?

Test your theoretical knowledge and diagnostic reasoning before tackling the practical lab missions:

*   **[Take the Section 040 Knowledge Check Quiz](./quiz.md)**

---

Each playground is ungraded: it spins up, prepares the environment, and waits. There is no task and no `astrona submit`. Tear one down with `astrona destroy <name>` when you are finished — the name is printed in each module's playground callout.
