# Section 010: Installing Istio With istioctl Or Helm

Welcome aboard, astronaut. Everything Istio does sits on top of one control plane process, `istiod`. Think of it as mission control for your fleet: it sends every ship's communications officer (the sidecar proxy) their orders. This section is about building mission control in your solar system (your cluster), twice, with the two methods the exam names, so that neither one is the only tool you have.

The two modules install the same control plane, configured through the same tree of values. What differs is who owns the result. `istioctl`, your launch console, draws a complete blueprint and makes the cluster match it. Helm assembles three separate kits (releases) whose order is a dependency, not a habit. A cluster is managed by one or the other, never both, and knowing why is most of the point.

**Exam topic covered:** Installing Istio with istioctl or Helm

---

## What You Will Master

- What `istioctl install` really does: drawing the objects on your machine plus an apply, with no operator in the cluster, and what a second run does to settings you left out.
- The built-in profiles (`default`, `demo`, `minimal`, `ambient`), and reading a profile's real contents by printing it with `istioctl manifest generate`.
- The three kinds of object an install creates: the `istiod` Deployment, the admission webhooks, and optional gateways (the spaceport gates).
- Switching on sidecar injection for a namespace, and why labelling it changes nothing until the pods are created again.
- Finding a version mismatch between the client, the control plane and the data plane with `istioctl version` and `istioctl proxy-status`.
- The Istio Helm charts (`base`, `istiod`, `gateway`, plus `cni` and `ztunnel` for ambient mode) and why the install order is fixed.
- Supplying mesh settings from a Helm values file, and reading back what a release applied with `helm get values` and the live `istio` ConfigMap.

---

## Modules In This Section

Work through the modules in this order. Each part teaches one idea. A mission (a graded lab) comes right after the part it practises, and the last page of each module is a wrap-up. Each module has its own playground: launch it from the module's first page.

### [Install Istio With istioctl](module-01/course.md)

4 parts and 1 mission:

1. [The Render-And-Apply Pipeline](module-01/course-01-render-and-apply-pipeline.md)
2. [Profiles And The Objects They Produce](module-01/course-02-profiles-and-installed-objects.md)
3. [Injection And The Version Triad](module-01/course-03-injection-and-version-alignment.md)
4. [Reconciliation And Clean Removal](module-01/course-04-reconciliation-and-removal.md)
   - Mission: [Install Istio With istioctl Lab](module-01/labs/lab-01/question.md)
5. [Wrap-Up: Mission Debrief](module-01/course-05-wrap-up.md)

### [Install Istio With Helm](module-02/course.md)

3 parts and 1 mission:

1. [The Chart Model And Its Ordering](module-02/course-01-chart-model-and-ordering.md)
2. [Installing The Three Releases](module-02/course-02-installing-the-releases.md)
3. [Release State, Verification And Cleanup](module-02/course-03-release-state-and-verification.md)
   - Mission: [Install Istio With Helm Lab](module-02/labs/lab-01/question.md)
4. [Wrap-Up: Mission Debrief](module-02/course-04-wrap-up.md)

---

## Knowledge Check

Test what you know before the section's final mission: [Section 010 Knowledge Check](quiz.md).

---

## Section Capstone: Install And Onboard A Mesh

The final mission of this section. You get a clean cluster and a platform specification: three pinned Helm releases, a `NodePort` ingress gateway under a given release name in its own namespace, mesh-wide and sidecar default settings from one values file, one namespace fully in the mesh, and one namespace left out on purpose.

- Mission: [Install And Onboard A Mesh Capstone Lab](capstone/labs/lab-01/question.md)

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-010/capstone/labs/lab-01
```
