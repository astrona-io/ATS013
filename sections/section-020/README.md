# Section 020: Customizing Your Istio Installation

A built-in profile gets `istiod` running, but almost never the way a real cluster needs it. This section covers the two kinds of change you make after the first install: changing the installation itself, and deciding exactly which pods get a sidecar proxy, the Envoy container that Istio adds to a pod to carry its traffic.

Both modules share one lesson that is easy to miss: a change that applies cleanly is not the same as a change that takes effect. An `IstioOperator` field in the wrong layer, or an injection label on the wrong object, gives no error and no result.

**Exam topic covered:** Customizing your Istio installation

## What you will learn

- The four configuration layers in an `IstioOperator` document (`profile`, `components`, `meshConfig` and `values`) and which one owns a given setting.
- Writing an `IstioOperator` file that turns off a component, sets mesh-wide behaviour and sizes the control plane.
- Finding the live `meshConfig` in the `istio` ConfigMap, and using it to tell "the setting never arrived" apart from "the proxies do not have it yet".
- What a second `istioctl install` does to settings the new document does not mention, and why the installation belongs in a committed file.
- How injection works as a mutating admission webhook, and why it only ever happens when a pod is created.
- Opting a namespace in, excluding one workload and forcing one workload in, with the `sidecar.istio.io/inject` label on the exact field the webhook reads.
- Reading what injection adds to a pod with `istioctl kube-inject`, and excluding a port from traffic capture with an annotation.

## Modules in this section

Work through the modules in this order. Each part teaches one idea. A graded lab comes right after the part it practises, and the last page of each module is a summary. Each module has its own playground, which you start from the module's landing page.

### Customize An Istio Installation

1. The Four Configuration Layers
2. meshConfig: From File To ConfigMap To Proxy
3. Writing, Validating And Re-applying The Document
   - Lab: Customize An Istio Installation Lab
4. Summary

### Control Sidecar Injection

1. Injection As Admission Control
2. The Precedence Rules
   - Lab: Control Sidecar Injection Lab
3. What Injection Writes Into The Pod
   - Lab: Exclude A Port From Sidecar Traffic Capture Lab
4. Summary

## Knowledge check and capstone

After the last module, a short multiple-choice knowledge check tests your reasoning before you spend time on a cluster.

The section ends with the capstone lab, **Shape The Install, Then Choose Who Joins Capstone Lab**. The capstone combines both skills in one specification: a customized control plane across all four `IstioOperator` layers, including the sidecar default that only shows up on an injected pod, and an injection decision for three workloads across two namespaces, one of which must stay entirely out of the mesh. The task is on its own page. Start the capstone with:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-020/capstone/labs/lab-01
```

When you think you are done, send it for grading, and remove it afterwards:

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
astrona destroy ats-013-capstone-020
```
