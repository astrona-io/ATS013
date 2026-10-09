# Section 020: Customizing Your Istio Installation

Welcome back, astronaut. A stock profile gets mission control (`istiod`) running. It almost never gets it running the way your solar system needs. This section is about the two kinds of change you make afterwards: reshaping the installation itself, and deciding exactly which ships (pods) get a communications officer (the sidecar proxy).

Both modules share one lesson that is easy to miss until it costs you: a change that applies cleanly is not the same as a change that takes effect. An `IstioOperator` field in the wrong layer, or an injection label on the wrong object, gives no error and no result.

**Exam topic covered:** Customizing your Istio installation

---

## What You Will Master

- The four configuration layers in an `IstioOperator` document (`profile`, `components`, `meshConfig` and `values`) and which one owns a given setting.
- Writing an `IstioOperator` file that turns off a component, sets mesh-wide behaviour and sizes the control plane.
- Finding the live `meshConfig` in the `istio` ConfigMap, and using it to tell "the setting never arrived" apart from "the proxies do not have it yet".
- What a second `istioctl install` does to settings the new document does not mention, and why the installation belongs in a committed file.
- How injection works as a mutating admission webhook, and why it only ever happens when a pod is created.
- Opting a namespace in, excluding one workload and forcing one workload in, with the `sidecar.istio.io/inject` label on the exact field the webhook reads.
- Reading what injection adds to a pod with `istioctl kube-inject`.

---

## Modules In This Section

Work through the modules in this order. A mission (a graded lab) comes right after the part it practises, and the last page of each module is a wrap-up.

### [Customize An Istio Installation](module-01/course.md)

3 parts and 1 mission:

1. [The Four Configuration Layers](module-01/course-01-the-four-configuration-layers.md)
2. [meshConfig: From File To ConfigMap To Proxy](module-01/course-02-meshconfig-from-file-to-proxy.md)
3. [Writing, Validating And Re-applying The Document](module-01/course-03-writing-validating-reapplying.md)
   - Mission: [Customize An Istio Installation Lab](module-01/labs/lab-01/question.md)
4. [Wrap-Up: Mission Debrief](module-01/course-04-wrap-up.md)

### [Control Sidecar Injection](module-02/course.md)

3 parts and 1 mission:

1. [Injection As Admission Control](module-02/course-01-injection-as-admission-control.md)
2. [The Precedence Rules](module-02/course-02-the-precedence-rules.md)
   - Mission: [Control Sidecar Injection Lab](module-02/labs/lab-01/question.md)
3. [What Injection Writes Into The Pod](module-02/course-03-what-injection-writes.md)
4. [Wrap-Up: Mission Debrief](module-02/course-04-wrap-up.md)

---

## Knowledge Check

Test your reasoning before the capstone: [Section 020 Knowledge Check](quiz.md).

---

## Section Capstone: Shape The Install, Then Choose Who Joins

The capstone brings both modules together in one specification: a customized control plane across all four `IstioOperator` layers, including the sidecar default that only shows up on an injected pod, and an injection decision for three workloads across two namespaces, one of which must stay entirely out of the mesh.

Read the task in [`question.md`](capstone/labs/lab-01/question.md), then start the mission:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-020/capstone/labs/lab-01
```

When you think you are done, send it for grading, and remove it afterwards:

```bash
astrona submit -c sections/section-020/capstone/labs/lab-01
astrona destroy ats-013-capstone-020
```
