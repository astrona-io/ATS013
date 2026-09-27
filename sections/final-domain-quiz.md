# Final Domain Exam Simulator: Installation, Upgrade And Configuration

This is a closed-book simulation of the **Installation, Upgrade And Configuration** domain — 20% of the ICA exam. It draws on all four sections: installing with `istioctl` and Helm, customizing the installation, controlling sidecar injection, canary and in-place upgrades, and ambient mode with waypoint proxies.

**How to use it.** Work through all 15 questions under a **25 minute** cap, without notes, without a cluster, and without expanding any answer until you have finished. Then score yourself. Anything below 12/15 points at a section worth re-reading rather than a question worth memorising — the mapping is at the end.

---

### Question 1
`istioctl install --set profile=demo -y` completes. Which statement about the cluster is now true?
*   **A)** An Istio operator pod is running and will reconcile the `IstioOperator` resource continuously.
*   **B)** The `IstioOperator` document was rendered into plain Kubernetes manifests on your machine and applied; nothing in the cluster is reconciling it afterwards.
*   **C)** The `IstioOperator` was stored as a custom resource, which `istiod` watches.
*   **D)** The manifests were rendered server-side by `istiod` from the profile name you passed.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

`istioctl install` is client-side templating plus an apply: load the profile, overlay `--set` and `-f`, render to manifests, apply, wait. The `IstioOperator` is an *input format*, not an object doing work in the cluster. Older Istio really did run an in-cluster operator; that model is gone, which is why a hand-edit to an installed object persists until the next install overwrites it.
</details>

---

### Question 2
Which profile installs `istiod` plus **both** an ingress and an egress gateway?
*   **A)** `default`  **B)** `minimal`  **C)** `demo`  **D)** `ambient`

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

`default` installs `istiod` and the ingress gateway only; `minimal` installs `istiod` alone; `ambient` installs `istiod`, `istio-cni` and `ztunnel` and no gateways. Diffing `istioctl manifest generate --set profile=default` against the same command for `demo` shows the egress gateway objects as the only difference — a profile is a document you can render and diff, not a preset with hidden behaviour.
</details>

---

### Question 3
`helm install istiod istio/istiod -n istio-system` fails with `resource mapping not found ... ensure CRDs are installed first`. What is the fix?
*   **A)** Run `helm repo update` and retry.
*   **B)** Install `istio/base` first — it defines the CRDs that the `istiod` chart's objects depend on.
*   **C)** Create the `istio-system` namespace.
*   **D)** Add `--skip-crds`.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

The order `base` → `istiod` → `gateway` is a dependency, not a convention. The rejection comes from the **API server**, which does not know the kind, rather than from Helm detecting a missing chart dependency. Read the kind named in the error.
</details>

---

### Question 4
A gateway installed as `helm install edge-gw istio/gateway -n edge` is not selected by a `Gateway` resource matching `istio: ingressgateway`. Why?
*   **A)** `Gateway` resources only select workloads in `istio-system`.
*   **B)** The chart derives the Deployment name, Service name and pod labels from the **release name**, so the workload is labelled `istio: edge-gw`.
*   **C)** The gateway chart applies no `istio:` label.
*   **D)** The `Gateway` resource must live in the same namespace as the workload.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

The release name is part of the contract your traffic configuration depends on, not a cosmetic choice. Either rename the release or change the selector.
</details>

---

### Question 5
Which key sets the default CPU request for **every injected sidecar**?
*   **A)** `spec.components.pilot.k8s.resources.requests.cpu`
*   **B)** `spec.meshConfig.defaultConfig.proxyResources.cpu`
*   **C)** `spec.values.global.proxy.resources.requests.cpu`
*   **D)** `spec.components.proxy.k8s.resources.requests.cpu`

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

`components.pilot` sizes `istiod` — one Deployment. `values.global.proxy` sizes every sidecar — multiplied by every meshed pod. They look similar and configure completely different bills. You verify the second on an injected pod, not in the `istio` ConfigMap.
</details>

---

### Question 6
You install from `istio-custom.yaml`, which disables the egress gateway. A colleague later runs `istioctl install --set profile=demo -y`. What happens?
*   **A)** Nothing; the profile is unchanged.
*   **B)** The two inputs are merged.
*   **C)** The egress gateway returns, because the install reconciles the cluster to the document it was given.
*   **D)** The command fails with a conflict.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

Reconciliation deletes what the new document omits and restores what the profile contains. Istio tracks its own objects through ownership labels, so it knows exactly which ones to prune. This is the argument for one committed file per control plane, passed on every run.
</details>

---

### Question 7
A namespace carries `istio-injection=enabled`. You add `sidecar.istio.io/inject: "false"` to a Deployment's own `metadata.labels` and restart it. The pods are still injected. Why?
*   **A)** The label must be `"disabled"`, not `"false"`.
*   **B)** The webhook is registered against Pods and evaluates its selector against the Pod — the label must be on `spec.template.metadata.labels`.
*   **C)** Namespace labels always win over pod labels.
*   **D)** The change needs a second restart to take effect.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

A label on the Deployment is never copied to the pod unless it is in the template. The manifest applies cleanly and achieves nothing, which is what makes this the most expensive mistake in section 020. (Note *C* is wrong in general: the pod-template label beats the namespace in both directions.)
</details>

---

### Question 8
A namespace carries both `istio-injection=enabled` and `istio.io/rev=1-30-5`. Which control plane serves it?
*   **A)** Revision `1-30-5`.  **B)** The default control plane.  **C)** Neither.  **D)** Both.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

It follows from the webhook selectors, not from conflict-resolution logic: the default webhook requires `istio-injection: enabled`, and the revisioned webhook requires `istio.io/rev` **and** that `istio-injection` is absent. A namespace with both satisfies only the first — which is why a canary upgrade can appear to do nothing.
</details>

---

### Question 9
`helm upgrade istiod istio/istiod -n istio-system --version 1.30.5` runs with no other flags, on a release that was installed with `-f values.yaml`. What is the result?
*   **A)** Values are carried over automatically.
*   **B)** The release falls back to chart defaults, and the command reports success.
*   **C)** The upgrade fails.
*   **D)** Only keys still present in the new chart are kept.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

`helm upgrade` computes the release from chart defaults plus what you pass **on this run**. `--reuse-values` opts into carrying the previous set over, but it merges rather than replaces, so a `-f` file that removes a key does not remove it. One complete committed file passed every time avoids both traps.
</details>

---

### Question 10
`istioctl version` reports `control plane version: 1.30.5` and `data plane version: 1.29.8 (4 proxies)`. Traffic is healthy. What is this?
*   **A)** A broken upgrade that must be rolled back.
*   **B)** Supported version skew — the upgrade is incomplete until every injected workload, gateways included, is restarted.
*   **C)** A reporting bug in `istioctl`.
*   **D)** Normal steady state; proxies never match the control plane.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

A proxy's image is fixed at pod creation, so a control-plane upgrade cannot rewrite every pod's stored spec. Istio supports one minor version of skew precisely so a rolling upgrade is possible. It is a window to pass through, not a resting place — and it is why you never skip a minor version.
</details>

---

### Question 11
What does `istioctl install --set profile=minimal --set revision=1-30-5` do to running workloads?
*   **A)** Nothing. It creates a second control plane; no pod moves until it is recreated.
*   **B)** It migrates every meshed namespace to the new revision.
*   **C)** It replaces the existing control plane in place.
*   **D)** It restarts injected pods so they attach to the new revision.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: A**

A revision suffixes every namespaced object it owns, and reconciliation is scoped by the `istio.io/rev` ownership label — so the new install cannot see or prune the default revision's objects. Installing a revision is completely non-disruptive, which is the property that makes canary upgrades safe to start.
</details>

---

### Question 12
Every namespace has moved to revision `1-30-5` and been restarted. How do you retire the old control plane?
*   **A)** `istioctl uninstall --purge -y`
*   **B)** `istioctl uninstall --revision default -y`
*   **C)** `kubectl -n istio-system delete deployment istiod`
*   **D)** `istioctl tag remove default -y`

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

`--purge` removes **every** revision plus the shared cluster-scoped resources and CRDs — including the canary you just promoted. Deleting the Deployment by hand leaves its Service, webhook and cluster resources behind. Name the revision.
</details>

---

### Question 13
Why does enrolling a namespace in ambient mode not require restarting its pods?
*   **A)** Ambient proxies are injected lazily on the first request.
*   **B)** Enrollment changes node-level redirection and ztunnel's configuration — both outside the pod, which is never modified.
*   **C)** The kubelet re-reads the pod spec on every label change.
*   **D)** It does require a restart; the documentation is out of date.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

Sidecar injection mutates the pod spec, so it can only happen at admission. Ambient enrollment changes the redirection `istio-cni-node` programs and the workload state `istiod` pushes to ztunnel. The observable proof is that `AGE` keeps counting and `RESTARTS` stays 0 — and the same cheapness makes un-enrolling reversible.
</details>

---

### Question 14
In an ambient namespace with **no waypoint**, you apply an `AuthorizationPolicy` denying everything except HTTP `GET`. What happens?
*   **A)** ztunnel enforces it.
*   **B)** The policy is rejected at admission.
*   **C)** It is accepted, reports healthy, and has no effect — ztunnel is L4 and cannot read the method.
*   **D)** All traffic is denied because the rule cannot be evaluated.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

`AuthorizationPolicy` is one CRD spanning two layers. Rules on `principals`, namespaces or ports are L4 and enforceable by ztunnel; rules on methods, paths or headers are L7 and need an HTTP-aware proxy in the path. The silent no-op is the most common ambient-mode mistake, and it is a security problem: the restriction you believe is in place is not.
</details>

---

### Question 15
A waypoint is deleted from a namespace that relied on it for an L7 authorization rule. What is the immediate effect?
*   **A)** Traffic stops until it is recreated.
*   **B)** Traffic keeps flowing with mTLS and L4 policy intact, while the L7 rule silently stops being enforced.
*   **C)** ztunnel takes over the L7 rule.
*   **D)** The `AuthorizationPolicy` is deleted with it.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

Deleting a waypoint degrades the mesh to L4 rather than breaking it. Identity, encryption and L4 authorization are ztunnel's job and are untouched; HTTP routing, header manipulation, retries, timeouts and L7 authorization all go away — while the policy object remains, looking healthy. A waypoint's absence is indistinguishable from its silence.
</details>

---

## Scoring And What To Re-read

| Score | Reading |
| --- | --- |
| 14–15 | Domain solid. Move on to the capstones if you have not run them. |
| 12–13 | Close. Re-read the parts covering your specific misses. |
| 9–11 | Re-read the landing pages and the pitfall blocks for the weak sections. |
| Below 9 | Work the sections again with their playgrounds running alongside. |

Question-to-section mapping:

| Questions | Section |
| --- | --- |
| 1, 2, 3, 4 | [010 — Installing Istio With istioctl Or Helm](./section-010/README.md) |
| 5, 6, 7, 8 | [020 — Customizing Your Istio Installation](./section-020/README.md) |
| 9, 10, 11, 12 | [030 — Upgrading Istio (Canary, In-Place)](./section-030/README.md) |
| 13, 14, 15 | [040 — Installing Istio In Sidecar Or Ambient Mode](./section-040/README.md) |

Questions 7 and 8 both turn on the same idea — *which object does the webhook actually read?* — and questions 14 and 15 both turn on *which layer enforces this?*. If you missed either pair, that concept is worth a re-read rather than the individual questions.
