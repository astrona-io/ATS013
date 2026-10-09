# Install Istio In Ambient Mode

Astronaut, in sidecar mode every spaceship (pod) carries its own communications officer: an extra proxy container inside the pod. **Ambient mode** takes that officer off the ship. Shared relay towers, one on each launch pad (node), do the job for every ship docked there instead.

That one change has a big effect on daily work. Mission control (`istiod`) is the same, and it hands out the same ID badges (certificates). But a planet (namespace) now joins the mesh with one label, and no ship has to be relaunched. Mutual TLS, the secret handshake where both ships show their badges, still happens. It just happens on the node, not in the pod.

## Learning objectives

After this module you can:

- Name the parts the `ambient` profile installs next to `istiod`, and say what each one does.
- Explain how a pod's traffic reaches ztunnel without any change to the pod, and compare that with the sidecar's init container.
- Enroll and remove a namespace with the `istio.io/dataplane-mode` label, and explain why no pod is recreated.
- Check mesh membership with `istioctl ztunnel-config workload`, and say why `kubectl get pod` cannot answer that question here.
- Describe HBONE and read a workload identity from a ztunnel access log.
- Say what ztunnel can do on its own and what needs a waypoint proxy.

## Before you start

Every mission starts with a pre-flight check, astronaut. Make sure you have the knowledge this module expects, and know what is waiting in your playground.

### What you should already know

- **Kubernetes basics.** Namespaces, Deployments, Services, DaemonSets, and `kubectl logs` and `kubectl exec`.
- **Sidecar injection.** In sidecar mode, Istio adds an `istio-proxy` container to each new pod in a labelled namespace, and an init container (or the Istio CNI plugin) sends the pod's traffic through that proxy. Pods that were already running need a restart to get one. This module keeps comparing ambient mode with that picture.

### What is in your playground

Your playground is a training solar system: a single-node `kind` cluster with **`istioctl` 1.30.5** and **Istio 1.30.5 installed with the `ambient` profile**.

The planet **`ambient-demo`** is **not enrolled** in the mesh yet. It runs two ships:

| Ship | Its role |
| --- | --- |
| `notification-service` (Deployment `notification-service-v1`, nginx) | A ship that answers every signal, behind the `notification-service` Service on port `80` |
| `tester` (curl) | Your test shuttle: you send test signals from here |

Both pods have exactly one container, and they still have exactly one container at the end of this module. All commands run from your normal shell, with `kubectl` already pointed at the cluster.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## The parts of this module

1. [The Ambient Data Plane](./course-01-the-ambient-data-plane.md): what the `ambient` profile installs, why `istio-cni` and `ztunnel` run once per node, and how traffic reaches a proxy that is not inside the pod.
2. [Enrollment, Verification And The L4 Boundary](./course-02-enrollment-and-the-l4-boundary.md): the enrollment label and why nothing restarts, checking membership when container counts no longer help, reading identities from ztunnel's logs, and where ztunnel's abilities stop.
   - Mission: [Install Istio In Ambient Mode](./labs/lab-01/question.md)
3. [Wrap-Up: Mission Debrief](./course-03-wrap-up.md)

## Why this matters

Sidecar mode and ambient mode are two data planes for the same control plane. In sidecar mode one proxy per pod does everything. In ambient mode the work is split: ztunnel does the layer 4 work (who is talking, on which port, encrypted) for every enrolled pod, and you add a waypoint proxy only where you need layer 7 work (reading HTTP).

That gives you mesh identity and encryption across a whole cluster at low cost. A cluster can run both modes side by side, but one namespace uses only one mode. The exam expects you to install ambient mode, enroll workloads, and prove they are in the mesh.
