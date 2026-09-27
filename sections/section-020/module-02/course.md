# Control Sidecar Injection

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS013/tree/main/sections/section-020/module-02/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-020/module-02/playground
> astrona destroy ats-013-playground-020-02
> ```

"Enable Istio for this namespace" sounds like one switch. In practice a real namespace has a web service that belongs in the mesh, a log shipper that would break if its traffic were intercepted, and a batch job that must be meshed no matter what the namespace says. Getting each of those right is a matter of knowing exactly which label is read, on which object, and at what moment.

This module is short on new concepts and long on precision, because almost every injection problem is one of two things: the label is in the wrong place, or the pod was never recreated. Both are consequences of the mechanism, so the mechanism comes first.

## How this module is organised

1. **[Part 1 — Injection As Admission Control](./course-01-injection-as-admission-control.md)** — the admission path a pod travels, the two webhook entries that make the decision, and why the timing of that decision explains most injection surprises.
2. **[Part 2 — The Precedence Rules](./course-02-the-precedence-rules.md)** — namespace label, pod label and revision label: the exact order they are evaluated, what wins when they conflict, and the single field a `sidecar.istio.io/inject` label has to sit on.
3. **[Part 3 — What Injection Writes Into The Pod](./course-03-what-injection-writes.md)** — the containers, ports and iptables rules that get added, reading them with `istioctl kube-inject`, and how the CNI variant changes the picture.

## Learning objectives

After this module you can:

- Trace a pod through mutating admission and explain why labelling a namespace never affects pods that already exist.
- Name the two webhook entries Istio registers and say which decision each one makes.
- State the evaluation order of the namespace label, the pod-template label and the revision label, and predict the result when two of them conflict.
- Exclude a single workload from an injected namespace and force a single workload into an uninjected one, putting the label on the correct object.
- Describe the containers and ports injection adds, and explain how traffic is redirected into the proxy.
- Produce and read an injected manifest with `istioctl kube-inject`.

## Before you start

You should be comfortable with Deployments and pod templates in `kubectl`, and know what a sidecar is. [Section 010's istioctl module](../../section-010/module-01/course.md) installs the control plane that serves the webhook, and its Part 3 introduces the admission path this module takes apart.

The playground gives you a single-node `kind` cluster with **`istioctl` 1.30.5**, **Istio 1.30.5 installed with the `default` profile**, and a namespace **`inject-demo` that has no injection label**. It holds three Deployments with deliberately different needs:

- `notification-service` — an nginx web server that should be in the mesh.
- `logging-agent` — a busybox sleeper standing in for a log shipper that should stay out.
- `batch-job` — a busybox sleeper that should be meshed regardless of the namespace label.

Every pod currently has exactly one container. All commands run from your normal shell with `kubectl` pointed at the cluster.

## Where this fits

Injection is the boundary between "Istio is installed" and "this workload is in the mesh", and it is a *sidecar-mode* boundary specifically. Section 040's ambient mode moves the proxy out of the pod entirely, which removes this whole decision — enrollment there is a label with no admission step and no restart. Knowing the sidecar mechanism well is what makes that contrast meaningful rather than just a different label name.
