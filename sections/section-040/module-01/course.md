# Install Istio In Ambient Mode

In sidecar mode, Istio adds a proxy container to every pod in the mesh. **Ambient mode** is a second data plane that removes that container. The data plane is the set of proxies that carry the traffic between workloads. In ambient mode, one shared proxy per node, called `ztunnel`, carries the traffic for every pod on that node that is part of the mesh.

The control plane does not change. `istiod` is Istio's control plane: it turns Istio resources into proxy configuration and sends it, together with certificates, to every proxy. What changes is daily work. A namespace joins the mesh with one label, and no pod has to be created again. Mutual TLS (mTLS, where both sides of a connection check each other's certificate and the traffic is encrypted) still happens, but ztunnel does it on the node instead of a proxy inside the pod.

The split of work is the main idea of this module. ztunnel does the layer 4 work for every pod in the mesh: who is talking, on which port, and encryption. A separate proxy, called a waypoint, does layer 7 work (reading HTTP), and you add it only where you need it. A cluster can run both data planes side by side, but one namespace uses only one of them.

## Learning objectives

After this module you can:

- Name the components the `ambient` profile installs next to `istiod`, and say what each one does.
- Explain how a pod's traffic reaches ztunnel without any change to the pod, and compare that with the sidecar's init container.
- Add a namespace to the mesh and remove it again with the `istio.io/dataplane-mode` label, and explain why no pod is created again.
- Check mesh membership with `istioctl ztunnel-config workload`, and say why `kubectl get pod` cannot answer that question in ambient mode.
- Describe HBONE (HTTP-Based Overlay Network Environment) and read a workload identity from a ztunnel access log.
- Say what ztunnel can do on its own and what needs a waypoint proxy.

## Before you start

This module expects some Kubernetes knowledge and a basic picture of sidecar mode, because it keeps comparing the two data planes.

### What you should already know

- **Kubernetes basics.** Namespaces, Deployments, Services, DaemonSets, and `kubectl logs` and `kubectl exec`.
- **Sidecar injection.** In sidecar mode, Istio adds an `istio-proxy` container to each new pod in a labelled namespace, and an init container (or the Istio CNI plugin) sends the pod's traffic through that proxy. Pods that were already running need a restart to get one.

### What is in your playground

The playground is a single-node `kind` cluster with **`istioctl` 1.30.5** and **Istio 1.30.5 installed with the `ambient` profile**. You run every command from your normal shell, and `kubectl` already points at the cluster.

The namespace **`ambient-demo`** is **not yet part of the mesh**. It runs two workloads:

| Workload | What it is |
| --- | --- |
| `notification-service` (Deployment `notification-service-v1`, nginx) | A web server that answers every request, behind the `notification-service` Service on port `80` |
| `tester` (curl) | A client pod; you send every test request from here |

Both pods have exactly one container, and they still have exactly one container at the end of this module.

Start your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Read the parts in this order:

1. **The Ambient Data Plane:** what the `ambient` profile installs, why `istio-cni-node` and `ztunnel` run once per node, and how traffic reaches a proxy that is not inside the pod.
2. **Enrollment, Verification And The L4 Boundary:** the label that adds a namespace to the mesh and why nothing restarts, how to check membership when container counts no longer help, how to read identities from ztunnel's log, and where ztunnel's abilities stop. The graded lab "Install Istio In Ambient Mode" follows this part.

A summary closes the module.
