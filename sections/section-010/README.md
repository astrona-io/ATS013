# Section 010: Installing Istio With istioctl Or Helm

Everything Istio does sits on top of one control plane process, `istiod`. `istiod` turns Istio resources into proxy configuration and sends it, with certificates, to the sidecar proxy in every pod. This section installs that control plane twice, with the two methods the exam names: the `istioctl` command-line tool and the Istio Helm charts.

Both methods install the same control plane, configured through the same tree of values. What differs is which tool owns the result. `istioctl install` renders a complete set of objects on your machine and makes the cluster match it. Helm installs three separate releases whose order is a dependency, not a habit. A cluster is managed by one tool or the other, never both, and knowing why is most of the point.

**Exam topic covered:** Installing Istio with istioctl or Helm

## What you will learn

- What `istioctl install` does: it renders the objects on your machine and applies them, with no operator in the cluster, and a second run removes settings you left out.
- The built-in profiles (`default`, `demo`, `minimal`, `ambient`), and reading a profile's real contents with `istioctl manifest generate`.
- The objects an install creates: the `istiod` Deployment, the admission webhooks, the CRDs (Custom Resource Definitions) and optional gateways.
- Turning on sidecar injection for a namespace, and why the label changes nothing until the pods are created again.
- Finding a version mismatch between the client, the control plane and the data plane with `istioctl version` and `istioctl proxy-status`.
- The Istio Helm charts (`base`, `istiod`, `gateway`, plus `cni` and `ztunnel` for ambient mode) and why the install order is fixed.
- Supplying mesh settings from a Helm values file, and reading back what a release applied with `helm get values` and the live `istio` ConfigMap.
- Removing Istio completely with `istioctl uninstall --purge` or `helm uninstall`, and cleaning up what both leave behind.

## Modules in this section

Work through the modules in this order. Each part teaches one idea. A graded lab comes right after the part it practises, and the last page of each module is a summary. Each module has its own playground, which you start from the module's landing page.

### Install Istio With istioctl

1. The Render-And-Apply Pipeline
2. Profiles And The Objects They Produce
3. Injection And The Version Triad
   - Lab: Install Istio With istioctl Lab
4. Reconciliation And Clean Removal
   - Lab: Remove Istio Completely With istioctl Lab
5. Summary

### Install Istio With Helm

1. The Chart Model And Its Ordering
2. Installing The Three Releases
3. Release State And Verification
   - Lab: Install Istio With Helm Lab
4. Uninstall And Clean Removal
   - Lab: Remove An Istio Helm Install Completely Lab
5. Summary

## Knowledge check and capstone

After the last module, a short multiple-choice knowledge check tests your reasoning before you spend time on a cluster.

The section ends with the capstone lab, **Install And Onboard A Mesh Capstone Lab**. The capstone gives you a clean cluster and a platform specification: three pinned Helm releases, a `NodePort` ingress gateway under a given release name in its own namespace, mesh-wide and sidecar default settings from one values file, one namespace fully in the mesh, and one namespace left out on purpose. The task is on its own page. Start the capstone with:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-010/capstone/labs/lab-01
```

When you think you are done, send it for grading, and remove it afterwards:

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
astrona destroy ats-013-capstone-010
```
