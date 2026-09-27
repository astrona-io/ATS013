# Section 030: Upgrading Istio (Canary, In-Place)

Upgrading a service mesh means changing the thing every request already depends on. This section covers the three ways that happens in practice, and the one fact common to all of them: replacing the control plane does not move the data plane. Until every injected workload is restarted, you are running new control plane software against old proxies.

The modules build on each other. The Helm module teaches the value-handling mechanics that make any chart-driven upgrade safe. The canary module teaches the strategy production clusters should default to, where a second control plane runs beside the first and rollback is a label change. The in-place module teaches the simpler alternative and makes the trade-off explicit, so you can argue for either one.

**Curriculum item covered:** Upgrading Istio (Canary, In-Place)

---

## What You Will Master

- How `helm upgrade` computes a release's values, what `--reuse-values` and `--reset-values` really do, and why an upgrade can succeed while silently discarding your configuration.
- Recovering values that exist only inside a release, with `helm get values --revision`, and rolling a release back.
- What a **revision** is — a named control plane with its own injection webhook — and how to install one beside an existing control plane without disturbing it.
- Moving a namespace between control planes with `istio.io/rev`, and why `istio-injection` must be removed first.
- **Revision tags** as an alias, so an upgrade or a rollback is one command instead of one per namespace.
- Retiring an old revision in the correct order relative to restarting workloads.
- What an in-place upgrade replaces, how to pre-check it with the target binary, and why its rollback path is a second full data-plane restart.
- Version skew: what it is, that Istio supports one minor version of it, and how `istioctl proxy-status` makes it visible.

---

## The Learning Path

### 1. Upgrade And Reconfigure Istio With Helm
*   **Module Reader:** **[Module 1: Upgrade And Reconfigure Istio With Helm](./module-01/course.md)**
    1. [Where A Release Lives](./module-01/course-01-where-a-release-lives.md)
    2. [How `helm upgrade` Computes Values](./module-01/course-02-how-upgrade-computes-values.md)
    3. [Executing And Reverting An Upgrade](./module-01/course-03-executing-and-reverting.md)
*   **Hands-on Playground:** `sections/section-030/module-01/playground` — Istio 1.29.8 installed as three Helm releases, with a non-default values file that exists only inside the release.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/module-01/playground
    ```
*   **Practice Lab Sandbox:** **`sections/section-030/module-01/labs/lab-01`**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-030/module-01/labs/lab-01
    ```
*   **Hands-on Objective:** Recover a values file that exists only inside a Helm release, upgrade all three charts to a new version without losing any of it, apply one deliberate mesh change, and restart the data plane so no version skew remains.

### 2. Canary Upgrade With Revisions And Revision Tags
*   **Module Reader:** **[Module 2: Canary Upgrade With Revisions And Revision Tags](./module-02/course.md)**
    1. [Revisions: A Named Control Plane](./module-02/course-01-revisions-a-named-control-plane.md)
    2. [Selecting, Moving And Retiring A Revision](./module-02/course-02-selecting-moving-retiring.md)
*   **Hands-on Playground:** `sections/section-030/module-02/playground` — Istio 1.29.8 as the default control plane, an injected `canary-demo` namespace, and two `istioctl` binaries so the upgrade has to be deliberate.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/module-02/playground
    ```
*   **Practice Lab Sandbox:** **`sections/section-030/module-02/labs/lab-01`**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-030/module-02/labs/lab-01
    ```
*   **Hands-on Objective:** Stand a second control plane up beside the first, put a namespace behind a revision tag rather than a raw revision label, and move a running workload across — leaving the old control plane untouched.

### 3. In-Place Upgrade Of The Control Plane
*   **Module Reader:** **[Module 3: In-Place Upgrade Of The Control Plane](./module-03/course.md)**
    1. [Replacing The Control Plane](./module-03/course-01-replacing-the-control-plane.md)
    2. [Skew, Completion And The Cost Of Reverting](./module-03/course-02-skew-completion-and-reverting.md)
*   **Hands-on Playground:** `sections/section-030/module-03/playground` — Istio 1.29.8 with a two-replica injected workload, so version skew is visible mid-rollout, plus both `istioctl` binaries.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/module-03/playground
    ```
*   **Practice Lab Sandbox:** **`sections/section-030/module-03/labs/lab-01`**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-030/module-03/labs/lab-01
    ```
*   **Hands-on Objective:** Pre-check with the target binary, replace the single control plane in place rather than canarying it, then close the skew window across two replicas, a client pod and the ingress gateway.

### 4. Section Capstone Challenge
*   **Comprehensive Challenge:** **`sections/section-030/capstone/labs/lab-01` (A Complete Canary Migration)**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-030/capstone/labs/lab-01
    ```
*   **Hands-on Objective:** Run a canary upgrade end to end: install the new revision, put a fleet behind a tag, migrate both namespaces, restart every workload, and only then retire the old control plane by name — without taking the shared CRDs with it.

---

## Ready for Assessment?

Test your theoretical knowledge and diagnostic reasoning before tackling the practical lab missions:

*   **[Take the Section 030 Knowledge Check Quiz](./quiz.md)**

---

Each playground is ungraded: it spins up, prepares the environment, and waits. There is no task and no `astrona submit`. Tear one down with `astrona destroy <name>` when you are finished — the name is printed in each module's playground callout.
