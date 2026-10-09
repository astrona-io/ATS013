# Section 030: Upgrading Istio (Canary, In-Place)

Upgrading a service mesh means replacing the control plane that every request already depends on. This section covers the three ways that happens in practice, and the one fact they all share.

Replacing `istiod` does not change running pods. Every pod keeps the sidecar proxy it was created with, so until every pod restarts, a new control plane sends configuration to proxies that run an older version. That state is called version skew, and every upgrade has to end it.

The three modules build on each other. The first shows how Helm computes values during an upgrade, so a chart upgrade never loses your settings, and how to roll a release back. The second shows the canary upgrade: a second control plane next to the first, where going back is a label change. The third shows the simpler in-place upgrade and makes the trade-off clear, so you can argue for either one.

**Exam topic covered:** Upgrading Istio (canary, in-place)

## What you will learn

- How `helm upgrade` computes a release's values, what `--reuse-values` and `--reset-values` really do, and why an upgrade can succeed while it throws your settings away.
- Getting back values that exist only inside a release with `helm get values --revision`, and rolling a release back with `helm rollback`.
- What a **revision** is (a named control plane with its own injection webhook), and how to install one next to an existing control plane without disturbing it.
- Moving a namespace between control planes with `istio.io/rev`, and why `istio-injection` must be removed first.
- **Revision tags**, stable names that point at a revision, so an upgrade or a rollback is one command instead of one per namespace.
- Retiring an old revision in the right order relative to restarting workloads.
- What an in-place upgrade replaces, how to pre-check it with the target binary, and why going back costs a second full restart of the data plane.
- Version skew: what it is, that Istio supports one minor version of it, and how `istioctl version` and `istioctl proxy-status` make it visible.

## Modules in this section

Work through the modules in this order. Each part teaches one idea. A graded lab comes right after the part it practises, and the last page of each module is a summary. Each module has its own playground, which you start from the module's landing page.

### Upgrade And Reconfigure Istio With Helm

1. Where A Release Lives
2. How `helm upgrade` Computes Values
3. Upgrading In Order And Finishing The Job
   - Lab: Upgrade And Reconfigure Istio With Helm Lab
4. Rolling Back And A Safe Procedure
   - Lab: Roll Back A Helm Release Of istiod Lab
5. Summary

### Canary Upgrade With Revisions And Revision Tags

1. Revisions: A Named Control Plane
2. Moving A Namespace To A Revision
3. Revision Tags
   - Lab: Canary Upgrade With Revisions And Tags Lab
4. Retiring The Old Revision
   - Lab: Retire The Old Control Plane Revision Lab
5. Summary

### In-Place Upgrade Of The Control Plane

1. Replacing The Control Plane
2. Version Skew And Finishing The Upgrade
   - Lab: In-Place Upgrade Lab
3. The Cost Of Going Back
4. Summary

## Knowledge check and capstone

After the last module, a short multiple-choice knowledge check tests your reasoning before you spend time on a cluster.

The section ends with the capstone lab, **A Complete Canary Migration Capstone Lab**. The capstone runs a canary upgrade from start to finish: install the new revision, put two namespaces behind a tag, move and restart every workload, and only then remove the old control plane by name, without removing the shared CRDs (Custom Resource Definitions) with it. The task is on its own page. Start the capstone with:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/capstone/labs/lab-01
```

When you think you are done, send it for grading, and remove it afterwards:

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
astrona destroy ats-013-capstone-030
```
