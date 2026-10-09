# Section 020 Knowledge Check: Customizing Your Istio Installation

Test your understanding of the four `IstioOperator` configuration layers, the install-time / runtime boundary, and the injection precedence rules that decide which pods join the mesh.

---

## Scenario-Based Questions

### Question 1
A task says "every sidecar in the mesh should request 20m of CPU". Which key configures that?
*   **A)** `spec.components.pilot.k8s.resources.requests.cpu`
*   **B)** `spec.meshConfig.defaultConfig.proxyResources.cpu`
*   **C)** `spec.values.global.proxy.resources.requests.cpu`
*   **D)** `spec.components.proxy.k8s.resources.requests.cpu`

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

*   **Why C is correct:** `values.global.proxy` sets the defaults applied to every injected sidecar, and it is the key the injection template reads. It is also the one whose cost multiplies — 20m here is 20m per meshed pod, not 20m total. You verify it on an injected pod, not in the `istio` ConfigMap.
*   **Why others are incorrect:**
    *   *Option A* sizes `istiod` itself. `pilot` is the historical name of the control-plane component, and it is one Deployment.
    *   *Option B* invents a field. `meshConfig.defaultConfig` is real and carries proxy *behaviour* settings, not Kubernetes resource requests.
    *   *Option D* invents a component. There is no `components.proxy` — sidecars are not a deployed component, they are injected into other people's pods.
</details>

---

### Question 2
You install `istio-custom.yaml`, which disables the egress gateway and sets `accessLogFile`. A week later a colleague runs `istioctl install --set profile=demo -y` to "refresh" the install. What is the result?
*   **A)** Nothing changes; the second install is a no-op because the same profile is already in use.
*   **B)** The egress gateway comes back and `accessLogFile` disappears, because `istioctl install` reconciles the cluster to the document it was given.
*   **C)** The two documents are merged, so both sets of settings are live.
*   **D)** The command fails with a conflict against the existing installation.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `istioctl install` is declarative — it renders a complete desired state and reconciles the cluster to it. The stock `demo` profile enables the egress gateway and sets no `accessLogFile`, so both of your deviations revert. Nothing warns you, because from Istio's point of view the colleague asked for `demo` and got `demo`. This is the argument for one committed file per control plane, passed on every run.
*   **Why others are incorrect:**
    *   *Option A* assumes the profile name is the whole input; the previous overrides were part of a different document.
    *   *Option C* describes a merge that does not happen — values from previous runs are not carried over.
    *   *Option D* invents a conflict check; reconciliation is the normal, expected behaviour.
</details>

---

### Question 3
Your `IstioOperator` contains `name: istio-egress-gw` under `components.egressGateways` with `enabled: false`. The install succeeds and the egress gateway is still running. Why?
*   **A)** Gateways cannot be disabled once installed; they must be deleted with `kubectl`.
*   **B)** Component lists are matched by `name`. The profile's gateway is called `istio-egressgateway`, so your entry defined a *second*, disabled gateway and left the original alone.
*   **C)** `enabled: false` only prevents future upgrades of that component.
*   **D)** The field should be `disabled: true`.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `components.ingressGateways` and `components.egressGateways` are lists, because a cluster can run several of each, and entries are joined to the profile's entries by the `name` field. An unmatched name is not an error — it is a new list entry. `istioctl manifest generate -f <file>` reveals this immediately: the original egress gateway objects are still in the rendered manifest.
*   **Why others are incorrect:**
    *   *Option A* is false; disabling a component through the document is exactly how it is removed.
    *   *Option C* invents semantics for `enabled`.
    *   *Option D* invents a field name.
</details>

---

### Question 4
Which of these belongs in a **runtime** resource rather than in the installation?
*   **A)** Whether the mesh has an egress gateway at all.
*   **B)** The default access-log destination for every proxy in the mesh.
*   **C)** Retries and a timeout for calls to one specific service.
*   **D)** How many replicas `istiod` runs.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

*   **Why C is correct:** Per-service traffic behaviour is a `VirtualService` — an ordinary Kubernetes resource you apply and delete at any time, picked up by `istiod` within seconds. Reaching for an install-time change here means re-running the install and rolling the control plane for something that needed a `kubectl apply`.
*   **Why others are incorrect:**
    *   *Option A* is `spec.components` — which components are deployed.
    *   *Option B* is `spec.meshConfig` — a mesh-wide default. (Per-*workload* logging would be a runtime `Telemetry` resource, which is the distinction worth holding onto.)
    *   *Option D* is `spec.components.pilot.k8s` — sizing a deployed workload.
</details>

---

### Question 5
A Deployment carries `sidecar.istio.io/inject: "false"` on its own `metadata.labels`, in an injected namespace. After a rollout restart, what happens?
*   **A)** The workload is excluded from the mesh, as intended.
*   **B)** The pods are injected anyway — the webhook is registered against Pods and never sees the Deployment.
*   **C)** The API server rejects the Deployment.
*   **D)** The workload is excluded, but only until the next control-plane restart.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Istio's mutating webhook is registered against the `pods` resource, and its `objectSelector` is evaluated against the Pod being admitted. A label on the Deployment is never copied to the pod unless it is in `spec.template.metadata.labels`. The manifest applies cleanly, nothing errors, and the workload keeps getting a sidecar — which is what makes this the most expensive mistake in the section.
*   **Why others are incorrect:**
    *   *Option A* is the intent, not the result.
    *   *Option C* would happen with an unquoted `false` (a YAML boolean is not a valid label value), but a quoted string on the wrong object is perfectly valid.
    *   *Option D* invents a time dependency.
</details>

---

### Question 6
A namespace carries **both** `istio-injection=enabled` and `istio.io/rev=1-30-5`. Which control plane serves its workloads?
*   **A)** Revision `1-30-5`, because the more specific label wins.
*   **B)** The default control plane — `istio-injection` wins and the revision label is silently ignored.
*   **C)** Neither; the conflict makes the webhook skip the namespace entirely.
*   **D)** Both, with pods alternating between them.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** It follows from the webhook selectors rather than from any conflict-resolution logic. The default webhook requires `istio-injection: enabled`; the revisioned webhook requires `istio.io/rev` **and** that `istio-injection` is absent. A namespace carrying both satisfies only the first. This is why removing the old label is step one of moving a namespace to a revision, not a tidy-up afterwards — and it is the reason a canary upgrade can appear to do nothing.
*   **Why others are incorrect:**
    *   *Option A* assumes a specificity rule that does not exist here.
    *   *Option C* would require both selectors to fail, which is not the case.
    *   *Option D* invents non-deterministic behaviour.
</details>

---

### Question 7
You set `meshConfig.outboundTrafficPolicy.mode: REGISTRY_ONLY`. An application that calls a public API starts returning 502 from its sidecar. What is the correct interpretation?
*   **A)** The mesh is misconfigured and the setting should be reverted.
*   **B)** The setting is working: `REGISTRY_ONLY` blocks every destination not in the mesh registry, so an external host needs a `ServiceEntry` to be reachable.
*   **C)** The sidecar cannot resolve DNS for external hosts in this mode.
*   **D)** The 502 comes from the application, not from Istio.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `ALLOW_ANY` (the default) lets a meshed pod reach any host; `REGISTRY_ONLY` is deny-by-default for outbound. It is a useful security posture and it is also an outage if enabled without inventorying outbound dependencies first. The diagnostic tell is an immediate 502 from the proxy rather than a connection timeout, which would suggest a network path problem instead.
*   **Why others are incorrect:**
    *   *Option A* treats the intended behaviour as a fault. The fix is a `ServiceEntry`, or a deliberate decision to go back to `ALLOW_ANY`.
    *   *Option C* misattributes it to DNS.
    *   *Option D* is wrong — the request never reached the application.
</details>

---

### Question 8
Which command would have caught an indentation error that put `meshConfig` underneath `components` in your `IstioOperator` file?
*   **A)** `kubectl apply --dry-run=server -f istio-custom.yaml`
*   **B)** `istioctl manifest generate -f istio-custom.yaml`, by showing the rendered result without your setting in it
*   **C)** `istioctl proxy-status`
*   **D)** Nothing — the install would have failed with a schema error.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** A misplaced key becomes an *unknown field*, and an unknown field does not stop an install. `istioctl validate -f` catches many schema problems, but `istioctl manifest generate -f` is the stronger check because it shows the fully rendered result — if your override is not in the output, it did not take, whatever the reason.
*   **Why others are incorrect:**
    *   *Option A* validates against Kubernetes API schemas; an `IstioOperator` file passed to `istioctl` is not applied that way.
    *   *Option C* inspects running proxies, long after the mistake.
    *   *Option D* is the comforting assumption that makes this class of bug expensive — silently ignored is the normal outcome.
</details>

---

## Ready for the Capstone?

*   **[Section 020 Capstone: Shape The Install, Then Choose Who Joins](./capstone/labs/lab-01/question.md)**
