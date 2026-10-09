# Control Sidecar Injection

Astronaut, "switch on Istio for this planet" sounds like one switch. A real namespace (a planet) is rarely that simple. It may hold a web service that belongs in the mesh, a log shipper that would break if its signals were intercepted, and a batch job that must be in the mesh no matter what the planet says.

Sidecar injection is how a ship gets its communications officer: the sidecar proxy that handles every signal in and out. Getting each ship right comes down to knowing exactly which label is read, on which object, and at what moment.

This module has few new ideas and a lot of precision. Almost every injection problem is one of two things: the label is in the wrong place, or the pod was never recreated. Both follow from how injection works, so that comes first.

## Learning objectives

After this module you can:

- Follow a pod through mutating admission, and explain why labelling a namespace never changes pods that already exist.
- Name the two webhook entries Istio registers, and say which decision each one makes.
- Give the order in which the namespace label, the pod template label and the revision label are read, and predict the result when two of them disagree.
- Exclude one workload from an injected namespace and force one workload into an uninjected one, with the label on the correct object.
- Describe the containers and ports injection adds, and explain how traffic is sent into the proxy.
- Produce and read an injected manifest with `istioctl kube-inject`.

## Before you start

Every mission starts with a pre-flight check, astronaut. Make sure you have the knowledge this module expects, and know what is waiting in your playground.

### What you should already know

- **Kubernetes basics.** Deployments, pod templates, labels and `kubectl rollout restart`.
- **What a sidecar is.** A second container in the pod, next to the application. In Istio it is the `istio-proxy` container, an Envoy proxy that `istiod` (mission control) sends its orders to.

### What is in your playground

Your playground is a small training solar system: one `kind` cluster with **`istioctl` 1.30.5** and **Istio 1.30.5 installed with the `default` profile**. It has one planet, **`inject-demo`, with no injection label**. It holds three Deployments with deliberately different needs:

| Ship | What it is | What it needs |
| --- | --- | --- |
| `notification-service` | An nginx web server | Should be in the mesh |
| `logging-agent` | A busybox container standing in for a log shipper | Should stay out of the mesh |
| `batch-job` | A busybox container standing in for a batch job | Should be in the mesh, whatever the namespace says |

Every pod has exactly one container right now. All commands run from your normal shell, with `kubectl` already pointed at the cluster.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Work through the parts in this order. The mission comes right after the part it practises.

1. [Injection As Admission Control](./course-01-injection-as-admission-control.md): the path a pod takes through the API server, the two webhook entries that decide, and why the timing of that decision explains most injection surprises.
2. [The Precedence Rules](./course-02-the-precedence-rules.md): namespace label, pod label and revision label, the order they are read in, what wins when they disagree, and the one field a `sidecar.istio.io/inject` label must sit on.
   - Mission: [Control Sidecar Injection](./labs/lab-01/question.md)
3. [What Injection Writes Into The Pod](./course-03-what-injection-writes.md): the containers, ports and traffic rules that get added, reading them with `istioctl kube-inject`, and how the Istio CNI plugin changes the picture.
4. [Wrap-Up: Mission Debrief](./course-04-wrap-up.md)

## Why this matters

Injection is the line between "Istio is installed" and "this workload is in the mesh". On the exam, a task like "mesh this namespace, but keep that one workload out" is graded on the pods, not on your labels. Know where the label goes and when it is read, and you get it right the first time.
