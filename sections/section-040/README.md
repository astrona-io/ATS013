# Section 040: Installing Istio In Sidecar Or Ambient Mode

In sidecar mode, every pod carries its own proxy container. **Ambient mode** removes that container. A per-node proxy called **ztunnel** handles the traffic of every ambient pod on its node, so pods are never changed, and a namespace joins the mesh with one label instead of a restart of every workload.

ztunnel works at layer 4: it knows which workload sends a connection and on which port, and it gives the whole cluster workload identity and mutual TLS (mTLS) at low cost. It never reads HTTP. When a rule needs a path, a method or a header, you add a **waypoint proxy**, an Envoy proxy that you deploy only where layer 7 processing is needed.

Knowing which component handles each feature is the real subject of this section. It is what stops you debugging an `HTTPRoute` that was correct all along, with nothing in the path able to apply it.

**Exam topic covered:** Installing Istio in sidecar or ambient mode

## What you will learn

- The parts the `ambient` profile installs next to `istiod`: `istio-cni-node` and `ztunnel`, both DaemonSets (one pod per node), and what each one does.
- Why ambient enrollment takes effect without recreating pods, and what that changes in daily work.
- Enrolling and removing a namespace with the `istio.io/dataplane-mode` label.
- Checking mesh membership with `istioctl ztunnel-config workload`, and why counting containers cannot answer that question in ambient mode.
- HBONE (HTTP-Based Overlay Network Environment), the mTLS tunnel between ztunnels, and reading workload identities from ztunnel's own logs.
- The boundary: what ztunnel enforces on its own at layer 4 (identities and ports), and what needs a waypoint at layer 7 (HTTP).
- What a waypoint proxy is, which object `istioctl waypoint apply` creates, and how to scope it to a namespace or to one Service.
- The path a request takes through a waypoint, applying a Gateway API `HTTPRoute`, and proving layer 7 processing from the response.

## Modules in this section

Work through the modules in this order. Each part teaches one idea. A graded lab comes right after the part it practises, and the last page of each module is a summary. Each module has its own playground, which you start from the module's landing page.

### Install Istio In Ambient Mode

1. The Ambient Data Plane
2. Enrollment, Verification And The L4 Boundary
   - Lab: Install Istio In Ambient Mode Lab
3. Summary

### Add A Waypoint Proxy For L7 In Ambient Mode

1. What A Waypoint Is And How Traffic Reaches It
2. L7 Configuration Through A Waypoint
   - Lab: Waypoint Proxy For L7 Lab
3. Scoping And Removing Waypoints
   - Lab: Scope A Waypoint To One Service Lab
4. Summary

## Knowledge check and capstone

After the last module, a short multiple-choice knowledge check tests your reasoning before you spend time on a cluster.

The section ends with the capstone lab, **An Ambient Mesh With Selective L7 Capstone Lab**. The capstone combines both modules in one task. You enroll a namespace without recreating any pod, add a waypoint, and enforce an HTTP-method rule that ztunnel cannot enforce on its own. You prove both outcomes with live requests: `200` for `GET` and `403` for `DELETE`. The task is on its own page. Start the capstone with:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-040/capstone/labs/lab-01
```

When you think you are done, send it for grading, and remove it afterwards:

```sh
astrona submit -c sections/section-040/capstone/labs/lab-01
astrona destroy ats-013-capstone-040
```
