# Section 030: Upgrading Istio (Canary, In-Place)

Welcome back, astronaut. Upgrading a service mesh means changing the thing every signal already depends on: mission control. This section covers the three ways that happens in practice, and the one fact they all share.

Replacing mission control does not change the ships. Every pod keeps the communications officer (the sidecar proxy) it was launched with. Until every ship relaunches, a new mission control gives orders to officers running old software. That state is called version skew, and every upgrade has to end it.

The three modules build on each other. The first shows how Helm handles values during an upgrade, so a chart upgrade never loses your settings. The second shows the canary upgrade: a second mission control next to the first, where going back is a label change. The third shows the simpler in-place upgrade and makes the trade-off clear, so you can argue for either one.

**Exam topic covered:** Upgrading Istio (canary, in-place)

---

## What You Will Master

- How `helm upgrade` computes a release's values, what `--reuse-values` and `--reset-values` really do, and why an upgrade can succeed while quietly throwing your settings away.
- Getting back values that exist only inside a release with `helm get values --revision`, and rolling a release back.
- What a **revision** is (a named mission control with its own injection webhook), and how to install one next to an existing control plane without disturbing it.
- Moving a namespace between control planes with `istio.io/rev`, and why `istio-injection` must be removed first.
- **Revision tags**, call signs that point at a revision, so an upgrade or a rollback is one command instead of one per namespace.
- Retiring an old revision in the right order relative to restarting workloads.
- What an in-place upgrade replaces, how to pre-check it with the target binary, and why going back costs a second full restart of the data plane.
- Version skew: what it is, that Istio supports one minor version of it, and how `istioctl version` and `istioctl proxy-status` make it visible.

---

## Modules In This Section

Work through the modules in this order. Each part teaches one idea. A mission (a graded lab) comes right after the part it practises, and the last page of each module is a wrap-up.

### [Upgrade And Reconfigure Istio With Helm](module-01/course.md)

4 parts and 1 mission:

1. [Where A Release Lives](module-01/course-01-where-a-release-lives.md)
2. [How `helm upgrade` Computes Values](module-01/course-02-how-upgrade-computes-values.md)
3. [Upgrading In Order And Finishing The Job](module-01/course-03-upgrading-in-order-and-finishing.md)
4. [Rolling Back And A Safe Procedure](module-01/course-04-rolling-back-and-a-safe-procedure.md)
   - Mission: [Upgrade And Reconfigure Istio With Helm Lab](module-01/labs/lab-01/question.md)
5. [Wrap-Up: Mission Debrief](module-01/course-05-wrap-up.md)

### [Canary Upgrade With Revisions And Revision Tags](module-02/course.md)

4 parts and 1 mission:

1. [Revisions: A Named Control Plane](module-02/course-01-revisions-a-named-control-plane.md)
2. [Moving A Namespace To A Revision](module-02/course-02-moving-a-namespace-to-a-revision.md)
3. [Revision Tags](module-02/course-03-revision-tags.md)
   - Mission: [Canary Upgrade With Revisions And Tags Lab](module-02/labs/lab-01/question.md)
4. [Retiring The Old Revision](module-02/course-04-retiring-the-old-revision.md)
5. [Wrap-Up: Mission Debrief](module-02/course-05-wrap-up.md)

### [In-Place Upgrade Of The Control Plane](module-03/course.md)

2 parts and 1 mission:

1. [Replacing The Control Plane](module-03/course-01-replacing-the-control-plane.md)
2. [Skew, Completion And The Cost Of Reverting](module-03/course-02-skew-completion-and-reverting.md)
   - Mission: [In-Place Upgrade Lab](module-03/labs/lab-01/question.md)
3. [Wrap-Up: Mission Debrief](module-03/course-03-wrap-up.md)

---

## Check Yourself, Then The Capstone

Before the capstone, test your reasoning with the **[Section 030 Knowledge Check](quiz.md)**.

Then fly the section capstone, **[A Complete Canary Migration](capstone/labs/lab-01/question.md)**. It runs a canary upgrade from start to finish: install the new revision, put two namespaces behind a tag, move and restart every workload, and only then retire the old control plane by name, without taking the shared Custom Resource Definitions with it.

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-030/capstone/labs/lab-01
```

When you think you are done, send it for grading with `astrona submit -c sections/section-030/capstone/labs/lab-01`, and remove it afterwards with `astrona destroy ats-013-capstone-030`.
