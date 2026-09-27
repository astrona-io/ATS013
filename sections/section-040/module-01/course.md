# Install Istio In Ambient Mode

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS013/tree/main/sections/section-040/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-040/module-01/playground
> astrona destroy ats-013-playground-040-01
> ```

Everything up to this point put a proxy inside the pod. Ambient mode does not. The mesh moves down to the node, mutual TLS and L4 authorization happen there, and your pod specs are never touched — which means joining the mesh costs a label instead of a rolling restart of every workload in the namespace.

That single difference changes the operational story more than it changes the concepts. The control plane is the same `istiod`, issuing the same certificates; what moved is where the proxying happens and how much of it you pay for.

## How this module is organised

1. **[Part 1 — The Ambient Data Plane](./course-01-the-ambient-data-plane.md)** — what the `ambient` profile installs, why `istio-cni` and `ztunnel` are DaemonSets rather than sidecars, and how traffic reaches a node-level proxy without the pod being modified.
2. **[Part 2 — Enrollment, Verification And The L4 Boundary](./course-02-enrollment-and-the-l4-boundary.md)** — the enrollment label and why no restart is needed, checking membership when container counts no longer help, reading HBONE identities out of ztunnel's logs, and exactly where ztunnel's capabilities stop.

## Learning objectives

After this module you can:

- Name the components the `ambient` profile adds beyond `istiod` and say what each is responsible for.
- Explain how traffic reaches ztunnel without any change to the pod, and contrast that with the sidecar init container.
- Enroll and un-enroll a namespace with `istio.io/dataplane-mode`, and explain why no pod is recreated.
- Verify mesh membership and transport protocol with `istioctl ztunnel-config`, and say why `kubectl get pod` cannot answer that question here.
- Describe HBONE and read a workload identity out of a ztunnel access log.
- State which capabilities ztunnel provides alone and which require a waypoint proxy.

## Before you start

You should understand sidecar injection and what the sidecar does for a workload — [section 020's injection module](../../section-020/module-02/course.md) covers both, and its Part 3 on traffic capture is the direct contrast Part 1 here builds on. Ambient mode is most easily understood as a redistribution of those same responsibilities.

The playground gives you a single-node `kind` cluster with **`istioctl` 1.30.5** and **Istio 1.30.5 installed with the `ambient` profile**. Namespace **`ambient-demo` is not yet enrolled** and runs `notification-service` (nginx) plus a `tester` pod. Both pods have exactly one container and will still have exactly one container at the end of this module.

All commands run from your normal shell with `kubectl` pointed at the cluster.

## Where this fits

Sidecar mode and ambient mode are two data planes for the same control plane. `istiod` is the same process, issuing the same certificates and serving the same Istio APIs; what differs is where the proxying happens.

In sidecar mode, one Envoy per pod does everything: mTLS, L4 policy, HTTP routing, retries, L7 authorization. In ambient mode that work is split. A per-node proxy called **ztunnel** handles the L4 half for every enrolled pod on that node. The L7 half is opt-in: you add a **waypoint proxy** for the namespaces or services that need HTTP-aware behaviour, and pay for Envoy only there — the next module.

The practical consequence is worth remembering as a sentence: ambient mode lets you get mesh identity and encryption across a whole cluster cheaply, then add L7 features selectively. A namespace can be in either mode, and both modes can coexist in one cluster — but not in one namespace.
