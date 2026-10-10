# Section 010 Knowledge Check: Installing Istio With istioctl Or Helm

Test what you know before the capstone lab. These questions check what `istioctl install` really does, how profiles are defined, the Helm chart model and its order, when injection happens, and how the three Istio versions decide whether a change takes effect.

---

## Scenario-Based Questions

### Question 1
You ran `istioctl install --set profile=demo -y` yesterday. Today a colleague edits the `istiod` Deployment by hand to add a node selector. What happens to that edit?
*   **A)** The in-cluster Istio operator reverts it within seconds, because `IstioOperator` is continuously reconciled.
*   **B)** It persists indefinitely — nothing in the cluster is watching — until the next `istioctl install`, which renders the Deployment from the profile and overwrites it.
*   **C)** It is rejected at admission, because the validating webhook protects control-plane objects.
*   **D)** It persists forever; `istioctl install` only creates objects and never updates existing ones.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `istioctl install` is client-side templating plus an apply. The `IstioOperator` document is an *input format*, not an object living in the cluster doing work. There is no reconciling controller, so a hand-edit survives — right up until someone re-runs the install, which is the worst possible duration because the revert is disconnected in time from the edit.
*   **Why others are incorrect:**
    *   *Option A* describes the old in-cluster operator model, which modern Istio no longer uses.
    *   *Option C* confuses the validating webhook, which checks Istio *configuration* resources like `VirtualService`, with control-plane workload objects.
    *   *Option D* is wrong in the other direction: the install reconciles, so it updates and even deletes objects it owns.
</details>

---

### Question 2
A task says "install Istio so that both an ingress and an egress gateway are running". Which profile satisfies it with no overrides?
*   **A)** `default`
*   **B)** `minimal`
*   **C)** `demo`
*   **D)** `ambient`

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

*   **Why C is correct:** `demo` is the profile that enables both gateways, along with more verbose telemetry. It is the fastest way to satisfy a task phrased this way, and diffing `istioctl manifest generate --set profile=default` against the same command for `demo` shows you exactly that the egress gateway objects are the difference.
*   **Why others are incorrect:**
    *   *Option A* installs `istiod` plus the **ingress** gateway only.
    *   *Option B* installs `istiod` and no gateways at all.
    *   *Option D* installs the ambient data plane — `istiod`, `istio-cni` and `ztunnel` — which is a different mode entirely, not a gateway choice.
</details>

---

### Question 3
`helm install istiod istio/istiod -n istio-system` fails with `resource mapping not found ... no matches for kind "EnvoyFilter"`. What is wrong?
*   **A)** The chart version is incompatible with your Helm version.
*   **B)** The `istio/base` chart has not been installed, so the CRDs that define Istio's kinds do not exist yet.
*   **C)** The `istio-system` namespace was not created.
*   **D)** The chart repository is stale and needs `helm repo update`.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** The `istiod` chart creates objects of kinds that `base` defines. Until the CRDs exist, the **API server** rejects them — this is not Helm detecting a missing dependency, it is Kubernetes refusing an unknown kind. That is why the order `base` → `istiod` → `gateway` is a dependency rather than a convention. Read the kind named in the error.
*   **Why others are incorrect:**
    *   *Option A* would produce a chart API-version error, not a missing-kind error.
    *   *Option C* produces a different, explicit error about the namespace not existing.
    *   *Option D* would mean the chart could not be found at all, which is a different message.
</details>

---

### Question 4
You add `istio-injection=enabled` to a namespace that already runs three Deployments. You check the pods a minute later and every pod still has one container. What is happening?
*   **A)** The webhook is broken — check that `istiod` is reachable.
*   **B)** Nothing is wrong. Injection is a mutating admission decision made at pod **creation**, so pods that already exist are unaffected until they are recreated.
*   **C)** The label is wrong; the correct one is `istio.io/inject=true` on the namespace.
*   **D)** Injection is asynchronous and can take up to five minutes to reconcile existing pods.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Istio registers a mutating webhook against the `pods` resource on the `CREATE` operation. The pods in question were admitted and stored before the webhook applied to their namespace, and admission cannot retroactively rewrite a stored object. `kubectl rollout restart deployment` is the step that actually performs the injection.
*   **Why others are incorrect:**
    *   *Option A* is the wrong diagnosis; if the webhook were unreachable you would see *new* pods failing to create, because its `failurePolicy` is `Fail`.
    *   *Option C* invents a label. The namespace labels are `istio-injection=enabled` or `istio.io/rev=<revision>`.
    *   *Option D* describes a reconciliation loop that does not exist for injection.
</details>

---

### Question 5
A cluster runs the `demo` profile. Someone runs `istioctl install --set profile=minimal -y` to "slim down the telemetry". What is the effect on the gateways?
*   **A)** Nothing — the gateways were installed separately and are unaffected.
*   **B)** Both gateway Deployments are deleted, because the rendered `minimal` document does not contain them and `istioctl install` reconciles the cluster to it.
*   **C)** The gateways are scaled to zero but their Deployments remain.
*   **D)** The command fails with a conflict, because components cannot be removed by an install.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `istioctl install` renders a complete desired state and reconciles the cluster to it. Istio tracks which objects it owns through labels such as `operator.istio.io/component` and `istio.io/rev`, lists the ones that are no longer in the rendered set, and deletes them. Components present only in the *previous* document go away, and the only signal is the absence of a tick in the install summary.
*   **Why others are incorrect:**
    *   *Option A* would be true for a *Helm* gateway release, which is a separate release, but not for gateways installed by an `istioctl` profile.
    *   *Option C* invents a scale-down behaviour; the objects are removed.
    *   *Option D* contradicts the declarative model — removal is exactly what reconciliation does.
</details>

---

### Question 6
You run `helm uninstall istio-base -n istio-system` and then `kubectl get crd | grep istio.io`, which still returns fifteen CRDs. Is something broken?
*   **A)** Yes — the uninstall failed partway through; re-run it.
*   **B)** No. Helm deliberately does not delete CRDs on uninstall, because deleting a CRD deletes every custom resource of that kind cluster-wide.
*   **C)** Yes — CRDs require `helm uninstall --purge`, which is the flag you forgot.
*   **D)** No, but they will be garbage-collected within the hour.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** This is documented Helm behaviour, not an Istio quirk. Removing a CRD cascades to every object of that kind in every namespace, which would be catastrophic if another release or another team depended on them. The consequence is that a cluster that looks clean to `helm` is not clean to Istio — the next install starts on top of stale definitions, which is exactly what `istioctl x precheck` warns about. Remove them explicitly, knowing what it deletes.
*   **Why others are incorrect:**
    *   *Option A* misreads expected behaviour as a failure.
    *   *Option C* invents a flag; `--purge` was a Helm 2 concept and is not how Helm 3 handles CRDs.
    *   *Option D* invents a garbage-collection path that does not exist for CRDs.
</details>

---

### Question 7
`istioctl proxy-status` shows an ingress gateway with `SYNCED` in `CDS`, `LDS` and `EDS`, but `NOT SENT` in `RDS`. What does that tell you?
*   **A)** The gateway is misconfigured and cannot receive route updates.
*   **B)** There is nothing of that resource type to send — no `Gateway` resource is attached yet, so there are no HTTP routes for this proxy.
*   **C)** The control plane is overloaded and deferring route pushes.
*   **D)** The gateway is running an older proxy version that does not support RDS.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** The four columns are Envoy's xDS resource types — Cluster, Listener, Endpoint and Route Discovery Service. `SYNCED` means the proxy acknowledged the current version, `STALE` means `istiod` sent an update and is waiting, and `NOT SENT` means there is simply nothing of that type for this proxy. A freshly installed gateway with no `Gateway` resource pointed at it has no routes, so `NOT SENT` under `RDS` is the healthy, expected state.
*   **Why others are incorrect:**
    *   *Option A* would show as `STALE` persisting, not `NOT SENT`.
    *   *Option C* also manifests as `STALE`.
    *   *Option D* would produce a version mismatch in `istioctl version`, not this column value.
</details>

---

### Question 8
You install the gateway chart with `helm install edge-gw istio/gateway -n edge`. A colleague's `Gateway` resource selecting `istio: ingressgateway` matches nothing. Why?
*   **A)** `Gateway` resources cannot select workloads outside `istio-system`.
*   **B)** The gateway chart derives its Deployment name, Service name and pod labels from the **release name**, so this workload is labelled `istio: edge-gw`, not `istio: ingressgateway`.
*   **C)** The `Gateway` resource must be created in `istio-system` regardless of where the gateway runs.
*   **D)** The gateway chart does not apply an `istio:` label at all; you must add it manually.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** The release name is not cosmetic — it becomes the object names *and* the selector labels, which is why it is part of the contract your traffic configuration depends on. A `Gateway` resource selects a gateway workload by label, so the selector has to match the labels the chart actually applied. Either rename the release or change the selector.
*   **Why others are incorrect:**
    *   *Option A* invents a namespace restriction; selecting a gateway in another namespace is the normal pattern.
    *   *Option C* is the same invented restriction from the other side.
    *   *Option D* is wrong — the chart does apply the labels, just derived from the release name.
</details>

---

### Question 9
After an upgrade, `istioctl version` reports `control plane version: 1.30.5` and `data plane version: 1.29.8 (4 proxies)`. Application traffic is working normally. What is the correct reading?
*   **A)** The mesh is broken and traffic is only working by luck; roll back immediately.
*   **B)** The upgrade is incomplete but supported — this is version skew, allowed across one minor version, and it ends when every injected workload (gateways included) is restarted.
*   **C)** The data plane will upgrade itself on the next xDS push.
*   **D)** `istioctl` is reporting stale cache; re-run it.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** A sidecar's image is fixed at pod creation, so upgrading the control plane — one Deployment — cannot rewrite the stored spec of every pod. Istio supports one minor version of skew precisely so a rolling upgrade is possible; without it there would be no safe intermediate state. The fix is `kubectl rollout restart` across every meshed namespace **and** the gateway Deployments, which are proxies too.
*   **Why others are incorrect:**
    *   *Option A* overreacts to a supported, expected state.
    *   *Option C* invents self-upgrading proxies; a container image only changes when the pod is replaced.
    *   *Option D* dismisses a real reading of the cluster.
</details>

---

## What comes next

The section capstone lab comes next. It combines the skills of the whole section in one task on a live cluster.
