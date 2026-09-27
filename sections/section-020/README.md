# Section 020: Customizing Your Istio Installation

A profile gets Istio running. It almost never gets Istio running the way a particular cluster needs it. This section is about the two kinds of change you make afterwards: reshaping the installation itself, and deciding precisely which pods join the mesh.

Both modules share a theme that is easy to miss until it costs you something — a change that applies cleanly is not the same as a change that takes effect. An `IstioOperator` field in the wrong layer, or an injection label on the wrong object, produces no error and no result.

**Curriculum item covered:** Customizing your Istio Installation

---

## What You Will Master

- The four configuration layers in an `IstioOperator` — `profile`, `components`, `meshConfig`, `values` — and which one owns a given setting.
- Writing an `IstioOperator` file that disables a component, sets mesh-wide behaviour, and sizes the control plane.
- Finding the live `meshConfig` in the `istio` ConfigMap, and using it to tell "the setting never arrived" apart from "the proxies have not got it yet".
- What a second `istioctl install` does to settings the new document does not mention, and why the installation belongs in a committed file.
- How injection works as a mutating admission webhook, and the consequence: it only ever applies at pod creation.
- Enabling injection per namespace, excluding one workload, and forcing one workload in — including the exact field a `sidecar.istio.io/inject` label must sit on.
- Reading what injection adds, with `istioctl kube-inject`.

---

## The Learning Path

### 1. Customize An Istio Installation
*   **Module Reader:** **[Module 1: Customize An Istio Installation](./module-01/course.md)**
    1. [The Four Configuration Layers](./module-01/course-01-the-four-configuration-layers.md)
    2. [meshConfig: From File To ConfigMap To Proxy](./module-01/course-02-meshconfig-from-file-to-proxy.md)
    3. [Writing, Validating And Re-applying The Document](./module-01/course-03-writing-validating-reapplying.md)
*   **Hands-on Playground:** `sections/section-020/module-01/playground` — a kind cluster with Istio 1.30.5 installed from the stock `demo` profile, as an unmodified baseline to deviate from.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-020/module-01/playground
    ```
*   **Practice Lab Sandbox:** **`sections/section-020/module-01/labs/lab-01`**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-020/module-01/labs/lab-01
    ```
*   **Hands-on Objective:** Deviate from a stock demo baseline across three IstioOperator layers at once — remove the egress gateway while keeping the ingress one, resize istiod, and put two mesh-wide settings live — then verify each change in the place that layer lands.

### 2. Control Sidecar Injection
*   **Module Reader:** **[Module 2: Control Sidecar Injection](./module-02/course.md)**
    1. [Injection As Admission Control](./module-02/course-01-injection-as-admission-control.md)
    2. [The Precedence Rules](./module-02/course-02-the-precedence-rules.md)
    3. [What Injection Writes Into The Pod](./module-02/course-03-what-injection-writes.md)
*   **Hands-on Playground:** `sections/section-020/module-02/playground` — a kind cluster with Istio 1.30.5 and an unlabelled `inject-demo` namespace holding three workloads with deliberately different injection needs.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-020/module-02/playground
    ```
*   **Practice Lab Sandbox:** **`sections/section-020/module-02/labs/lab-01`**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-020/module-02/labs/lab-01
    ```
*   **Hands-on Objective:** Produce a three-way injection matrix in one namespace: opted in at the namespace, one workload pulled out and one forced in, with every override label on the pod template the webhook actually reads.

### 3. Section Capstone Challenge
*   **Comprehensive Challenge:** **`sections/section-020/capstone/labs/lab-01` (Shape The Install, Then Choose Who Joins)**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-020/capstone/labs/lab-01
    ```
*   **Hands-on Objective:** Deliver a customized control plane across all four IstioOperator layers — including the sidecar default that only shows up on an injected pod — alongside a full injection matrix spanning two namespaces, one of which must stay entirely out of the mesh.

---

## Ready for Assessment?

Test your theoretical knowledge and diagnostic reasoning before tackling the practical lab missions:

*   **[Take the Section 020 Knowledge Check Quiz](./quiz.md)**

---

Each playground is ungraded: it spins up, prepares the environment, and waits. There is no task and no `astrona submit`. Tear one down with `astrona destroy <name>` when you are finished — the name is printed in each module's playground callout.
