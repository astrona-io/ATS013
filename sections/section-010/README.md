# Section 010: Installing Istio With istioctl Or Helm

Every other thing Istio does sits on top of one control plane process. This section is about getting that process onto a cluster — twice, by the two methods the ICA curriculum names, so that neither one is the only tool you have.

The two modules install the same control plane and are configured through the same value tree. What differs is ownership: `istioctl` renders a document and reconciles the cluster to it, while Helm manages three separate releases whose order is a dependency, not a convention. A cluster should be managed by one or the other, never both, and knowing why is most of the point.

**Curriculum item covered:** Installing Istio with istioctl or Helm

---

## What You Will Master

- What `istioctl install` actually does — client-side rendering plus an apply, with no in-cluster operator — and what a second run does to settings you left out.
- The built-in profiles (`default`, `demo`, `minimal`, `ambient`), and reading a profile's real definition by rendering it with `istioctl manifest generate`.
- The three kinds of object an install creates: the `istiod` Deployment, the admission webhooks, and optional gateways.
- Enabling sidecar injection for a namespace, and why labelling it changes nothing until pods are recreated.
- Diagnosing client / control-plane / data-plane version mismatch with `istioctl version` and `istioctl proxy-status`.
- The Istio Helm charts — `base`, `istiod`, `gateway`, plus `cni` and `ztunnel` for ambient — and why the install order is fixed.
- Supplying mesh settings from a Helm values file, and reading back what a release applied with `helm get values` and the live `istio` ConfigMap.

---

## The Learning Path

### 1. Install Istio With istioctl
*   **Module Reader:** **[Module 1: Install Istio With istioctl](./module-01/course.md)**
    1. [The Render-And-Apply Pipeline](./module-01/course-01-render-and-apply-pipeline.md)
    2. [Profiles And The Objects They Produce](./module-01/course-02-profiles-and-installed-objects.md)
    3. [Injection And The Version Triad](./module-01/course-03-injection-and-version-alignment.md)
    4. [Reconciliation And Clean Removal](./module-01/course-04-reconciliation-and-removal.md)
*   **Hands-on Playground:** `sections/section-010/module-01/playground` — a clean kind cluster with `istioctl` 1.30.5 and no Istio installed.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-010/module-01/playground
    ```
*   **Practice Lab Sandbox:** **`sections/section-010/module-01/labs/lab-01`**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-010/module-01/labs/lab-01
    ```
*   **Hands-on Objective:** Install a demo-profile control plane from nothing, confirm the CRDs and injection webhook it created, then get an already-running workload into the mesh and prove control plane and data plane agree on a version.

### 2. Install Istio With Helm
*   **Module Reader:** **[Module 2: Install Istio With Helm](./module-02/course.md)**
    1. [The Chart Model And Its Ordering](./module-02/course-01-chart-model-and-ordering.md)
    2. [Installing The Three Releases](./module-02/course-02-installing-the-releases.md)
    3. [Release State, Verification And Cleanup](./module-02/course-03-release-state-and-verification.md)
*   **Hands-on Playground:** `sections/section-010/module-02/playground` — a clean kind cluster with `helm` 3, `istioctl` 1.30.5, and the `istio` chart repository added.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-010/module-02/playground
    ```
*   **Practice Lab Sandbox:** **`sections/section-010/module-02/labs/lab-01`**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-010/module-02/labs/lab-01
    ```
*   **Hands-on Objective:** Install the same control plane as three pinned Helm releases in the correct order, put the ingress gateway in its own namespace under its own release name, drive mesh settings from a values file, and prove the injection webhook the chart created actually works.

### 3. Section Capstone Challenge
*   **Comprehensive Challenge:** **`sections/section-010/capstone/labs/lab-01` (Install And Onboard A Mesh)**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-010/capstone/labs/lab-01
    ```
*   **Hands-on Objective:** Deliver a full platform specification on a clean cluster — three pinned Helm releases, a NodePort ingress gateway under a given release name in its own namespace, mesh-wide and sidecar-default settings from one values file, one namespace fully meshed with the configured proxy resources, and one namespace deliberately left out of the mesh.

---

## Ready for Assessment?

Test your theoretical knowledge and diagnostic reasoning before tackling the practical lab missions:

*   **[Take the Section 010 Knowledge Check Quiz](./quiz.md)**

---

Each playground is ungraded: it spins up, prepares the environment, and waits. There is no task and no `astrona submit`. Tear one down with `astrona destroy <name>` when you are finished — the name is printed in each module's playground callout.
