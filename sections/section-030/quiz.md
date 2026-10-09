# Section 030 Knowledge Check: Upgrading Istio (Canary, In-Place)

Check what you know before the capstone lab. These questions test how Helm handles values on an upgrade, revisions and revision tags, version skew, and the order of steps that decides whether an upgrade leaves your workloads stranded.

---

## Scenario-Based Questions

### Question 1
`istiod` was installed with `-f values.yaml`. Someone runs `helm upgrade istiod istio/istiod -n istio-system --version 1.30.5` with no other flags. It prints `STATUS: deployed`. What happened to the values?
*   **A)** They were carried over automatically; only the chart version changed.
*   **B)** They were discarded. The release now uses chart defaults, and the command reported success.
*   **C)** The upgrade would have failed, because Helm requires the original values file.
*   **D)** They were carried over, but only the keys that still exist in the new chart.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `helm upgrade` computes the release from the chart's defaults plus the `-f` files and `--set` flags given **on this run**. Values from the previous revision are not carried over. Nothing errors, the exit code is zero, and mesh-wide settings quietly revert. The habit that removes the problem entirely: one complete values file, committed, passed with `-f` on every install and every upgrade.
*   **Why others are incorrect:**
    *   *Option A* describes `--reuse-values`, which is opt-in.
    *   *Option C* invents a safety check Helm does not perform.
    *   *Option D* invents partial carry-over.
</details>

---

### Question 2
You need to recover the values an existing release was installed with, because nobody committed the file. Which command gives them to you?
*   **A)** `helm show values istio/istiod`
*   **B)** `helm get values istiod -n istio-system --revision 1`
*   **C)** `kubectl -n istio-system get cm istio -o yaml`
*   **D)** `istioctl manifest generate --set profile=istiod`

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Helm stores each release revision — rendered manifests and the values used — in a Secret in the release's namespace, and keeps old revisions. `helm get values --revision N` reads the values back out. Strip the `USER-SUPPLIED VALUES:` header line, which is for humans and not part of the YAML, then commit the result.
*   **Why others are incorrect:**
    *   *Option A* prints the **chart's defaults**, not what anyone supplied.
    *   *Option C* shows the live `meshConfig` only — real and useful as a fallback, but it misses `pilot`, `global.proxy` and anything that was set without a visible effect.
    *   *Option D* is not a valid invocation; `istiod` is a release name, not a profile, and `manifest generate` renders install input rather than reading a release.
</details>

---

### Question 3
After `helm upgrade` of `istiod` to 1.30.5, `istioctl version` reports `control plane version: 1.30.5` and `data plane version: 1.29.8 (4 proxies)`. Traffic is fine. What is the correct action?
*   **A)** Roll back immediately; the mesh is in an unsupported state.
*   **B)** Restart every injected workload, gateways included, to bring the data plane to 1.30.5.
*   **C)** Wait — proxies pick up the new version on the next xDS push.
*   **D)** Re-run the upgrade with `--force`.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** A proxy's image is fixed at pod creation, so upgrading the control plane — one Deployment — cannot rewrite the stored spec of every pod. This is version skew, supported across one minor version, and it ends only when pods are replaced. Gateways count: they are Envoy workloads with no namespace label driving them, and they are the most commonly forgotten.
*   **Why others are incorrect:**
    *   *Option A* overreacts to a supported, expected intermediate state.
    *   *Option C* invents self-upgrading proxies; a container image changes only when the pod is replaced.
    *   *Option D* re-applies the same manifests and does nothing about the data plane.
</details>

---

### Question 4
What does `istioctl install --set profile=minimal --set revision=1-30-5` create?
*   **A)** It replaces the existing `istiod` with a minimal installation named `1-30-5`.
*   **B)** A second control plane — `istiod-1-30-5` with its own Service and its own injection webhook — alongside the existing one.
*   **C)** A tag pointing at the current control plane.
*   **D)** Nothing until a namespace is labelled; the command is a no-op otherwise.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** A revision adds its name as a suffix to every namespaced object the install owns, so names do not collide. Istio's reconciliation is scoped by the `istio.io/rev` ownership label, which means this install cannot see or prune the default revision's objects — that scoping is precisely what lets two control planes coexist. Installing a revision is completely non-disruptive: no running pod moves.
*   **Why others are incorrect:**
    *   *Option A* describes an in-place upgrade, which is what happens when you omit `revision`.
    *   *Option C* describes `istioctl tag set`.
    *   *Option D* is half right about the effect on workloads but wrong about the cluster — real objects are created.
</details>

---

### Question 5
Why prefer `istio.io/rev=prod` (a tag) over `istio.io/rev=1-30-5` (a raw revision) on your namespaces?
*   **A)** Tags are validated by the API server; raw revisions are not.
*   **B)** Because upgrading then means moving one tag rather than relabelling every namespace — and rolling back is the same single command.
*   **C)** Raw revision labels are deprecated in recent Istio versions.
*   **D)** Tags allow a namespace to use two control planes at once.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** A tag is an alias — mechanically, another mutating webhook configuration whose selector matches `istio.io/rev=<tag>` and whose backend is the tagged revision's control plane. With fifty namespaces, relabelling each one is fifty chances to miss one, and a missed namespace is a workload left on a control plane you are about to delete. Moving the tag rewrites one webhook's backend, and workloads follow it when they are next restarted.
*   **Why others are incorrect:**
    *   *Option A* invents a validation difference.
    *   *Option C* is false; raw revision labels remain supported and are the right tool for pinning one workload.
    *   *Option D* invents a capability — a workload is served by exactly one control plane.
</details>

---

### Question 6
You have moved every namespace to revision `1-30-5` and restarted the workloads. How do you retire the old control plane?
*   **A)** `istioctl uninstall --purge -y`
*   **B)** `istioctl uninstall --revision default -y`
*   **C)** `kubectl -n istio-system delete deployment istiod`
*   **D)** `istioctl tag remove default -y`

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `--revision <name>` removes one named control plane and the objects labelled for it, leaving other revisions and the shared cluster-wide resources intact, including the Custom Resource Definitions (CRDs). That is exactly what retiring a revision after a canary means.
*   **Why others are incorrect:**
    *   *Option A* removes **every** revision, including the one you just promoted, plus the shared CRDs. This is the destructive mistake the section warns about repeatedly.
    *   *Option C* deletes one object and leaves its Service, webhook and cluster-scoped resources behind — a half-removed control plane that the next `precheck` will complain about.
    *   *Option D* removes a tag, not a control plane.
</details>

---

### Question 7
What goes wrong if you uninstall the old revision **before** restarting the workloads that still use it?
*   **A)** Nothing; the workloads are immediately re-attached to the remaining control plane.
*   **B)** Traffic stops instantly for every affected pod.
*   **C)** The pods keep serving on their last-received configuration, but receive no further updates and cannot renew their workload certificates — so they fail later, in a way that looks unrelated.
*   **D)** The uninstall is rejected while proxies are still connected.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

*   **Why C is correct:** A proxy holds its configuration locally and does not need `istiod` to forward a request. What it loses is everything *ongoing*: routing and endpoint updates as pods come and go, and certificate renewal when the current one expires. The delayed, disconnected failure is exactly what makes the ordering rule worth memorising — restart first, uninstall second.
*   **Why others are incorrect:**
    *   *Option A* invents automatic re-attachment; the proxy's control-plane address was set at injection.
    *   *Option B* overstates the immediate impact, which is what makes the mistake easy to miss.
    *   *Option D* invents a safety interlock.
</details>

---

### Question 8
Which statement about an **in-place** upgrade is true?
*   **A)** It keeps the previous control plane running so a rollback is a label change.
*   **B)** It reuses the same revision, so `istiod` keeps its name and object identity — and rolling back means reinstalling the old version and restarting the whole data plane again.
*   **C)** It restarts injected workloads automatically as part of the install.
*   **D)** It is the only upgrade path supported for Helm-managed installations.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** "In place" is a statement about object identity: the Deployment keeps its name and its `uid`, and Kubernetes rolls its pods. That is the appeal — nothing to relabel — and the risk, because there is nothing left to fall back to. The rollback is a second full data-plane restart, performed while something is already going wrong, which is the honest argument for canary in production.
*   **Why others are incorrect:**
    *   *Option A* describes a canary upgrade.
    *   *Option C* is the omission the whole section warns about; the install never touches your pods.
    *   *Option D* is false — a Helm version bump behaves like an in-place upgrade, but `istioctl` can do either, and Helm is not restricted to one strategy.
</details>

---

### Question 9
Why must you not upgrade from 1.28 directly to 1.30?
*   **A)** Istio does not publish charts that skip a minor version.
*   **B)** The CRDs cannot be upgraded by more than one version at a time.
*   **C)** During the upgrade every running proxy would be two minor versions behind the control plane, outside the supported one-minor skew window.
*   **D)** `istioctl x precheck` refuses to run across two minors.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

*   **Why C is correct:** The supported skew window is one minor version between control plane and proxies, and it applies per workload. Jumping two minors means every pod is outside that window for the whole duration of the upgrade, with no guarantee about what the old proxies do with the configuration they are sent. Go 1.28 → 1.29, restart the data plane, then 1.29 → 1.30.
*   **Why others are incorrect:**
    *   *Option A* is false; every published chart version is installable.
    *   *Option B* invents a CRD constraint.
    *   *Option D* invents a refusal — `precheck` warns, it does not block.
</details>

---

## What comes next

The section capstone lab comes next. It combines the skills of the whole section in one task on a live cluster.
