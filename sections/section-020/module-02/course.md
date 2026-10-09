# Control Sidecar Injection

"Turn on Istio for this namespace" sounds like one switch. A real namespace is rarely that simple. It may hold a web service that belongs in the mesh, a log shipper that breaks if a proxy captures its traffic, and a batch job that must be in the mesh whatever the namespace says.

**Sidecar injection** is the step that adds the sidecar proxy to a pod. The sidecar proxy is an Envoy container, `istio-proxy`, that handles all inbound and outbound traffic of the pod. Getting each workload right comes down to one question: which label does Istio read, on which object, and at what moment?

This module has few new ideas and needs a lot of precision. Almost every injection problem is one of two things: the label is on the wrong object, or the pod was never created again after the change. Both follow from how injection works, so the module starts there.

## Learning objectives

After this module you can:

- Follow a pod through mutating admission, and explain why labelling a namespace never changes pods that already exist.
- Name the two webhook entries Istio registers, and say which decision each one makes.
- Give the order in which the namespace label, the pod template label and the revision label are read, and predict the result when two of them disagree.
- Exclude one workload from an injected namespace and force one workload into a namespace without injection, with the label on the correct object.
- Describe the containers and ports injection adds, and explain how traffic is sent into the proxy.
- Produce and read an injected manifest with `istioctl kube-inject`, and exclude one port from traffic capture with an annotation.

## Before you start

This module expects some Kubernetes knowledge and a basic idea of what a sidecar is. The playground has everything else ready.

### What you should already know

- **Kubernetes basics.** Deployments, pod templates, labels and `kubectl rollout restart`.
- **What a sidecar is.** A second container in the pod, next to the application. In Istio it is the `istio-proxy` container, an Envoy proxy that gets its configuration from `istiod`, the Istio control plane.

### What is in your playground

The playground is one single-node `kind` cluster with **`istioctl` 1.30.5** and **Istio 1.30.5 installed with the `default` profile**. It has one namespace, **`inject-demo`, with no injection label**. The namespace holds three Deployments with different needs:

| Deployment | What it is | What it needs |
| --- | --- | --- |
| `notification-service` | An nginx web server | Should be in the mesh |
| `logging-agent` | A busybox container that stands in for a log shipper | Should stay out of the mesh |
| `batch-job` | A busybox container that stands in for a batch job | Should be in the mesh, whatever the namespace label says |

Every pod has exactly one container right now. You run every command from your normal shell, and `kubectl` already points at the cluster.

Start your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Read the parts in this order:

1. **Injection As Admission Control:** the path a pod takes through the Kubernetes API server, the two webhook entries that decide, and why the timing of that decision explains most injection surprises.
2. **The Precedence Rules:** the namespace label, the pod label and the revision label, the order Istio reads them in, what wins when they disagree, and the one field a `sidecar.istio.io/inject` label must sit on. The graded lab "Control Sidecar Injection" follows this part.
3. **What Injection Writes Into The Pod:** the containers, ports and traffic rules injection adds, how to read them with `istioctl kube-inject`, how to exclude a port from capture, and how the Istio CNI plugin changes the picture. The graded lab "Exclude A Port From Sidecar Traffic Capture" follows this part.

A summary closes the module.
