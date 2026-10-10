# Solution Walkthrough

Follow these steps to install the Istio control plane (`istiod`), bring the existing workload into the mesh, and prove that the versions match.

---

## Step 1: Check the starting state

Confirm the cluster really is clean before you change anything. The first command is *expected* to fail, and the second is expected to print only a header line:

```sh
kubectl get ns istio-system
kubectl api-resources --api-group=networking.istio.io
```

```text
Error from server (NotFound): namespaces "istio-system" not found
NAME   SHORTNAMES   APIVERSION   NAMESPACED   KIND
```

There is no `istio-system` namespace, and the API server knows no resource in the `networking.istio.io` API group, because no Istio CRDs are installed.

Now run the pre-install check:

```sh
istioctl x precheck
```

```text
✔ No issues found when checking the cluster. Istio is safe to install or upgrade!
  To get started, check out https://istio.io/latest/docs/setup/getting-started/.
```

`x` is short for `experimental`. `precheck` only reads. It asks whether *this cluster* can accept Istio: it looks at the Kubernetes version, leftover CRDs and webhooks that would get in the way. It is a statement about the cluster, not about your configuration.

---

## Step 2: Install the control plane

```sh
istioctl install --set profile=demo -y
```

The output looks like this (shortened: the progress lines and the logo are left out):

```text
✔ Istio core installed ⛵️
✔ Istiod installed 🧠
✔ Ingress gateways installed 🛬
✔ Egress gateways installed 🛫
✔ Installation complete
```

`-y` skips the confirmation question. The command waits until the components report ready, so when it returns, the control plane really is up.

Read the summary carefully: those ticks are the profile's list of components. **`demo` is the profile that installs both gateways.** `default` installs only the ingress gateway, and `minimal` installs neither. If your summary has no "Egress gateways installed" line, you installed the wrong profile.

`istioctl install` rendered the profile into plain Kubernetes objects on your machine and applied them. No operator pod stays in the cluster afterwards to keep anything in place.

---

## Step 3: Confirm what the install created

List the Deployments in `istio-system`:

```sh
kubectl -n istio-system get deploy
```

```text
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
istio-egressgateway    1/1     1            1           8s
istio-ingressgateway   1/1     1            1           8s
istiod                 1/1     1            1           20s
```

Three Deployments: the control plane and both gateways. A gateway is not a special component. It is an ordinary Deployment running the same Envoy image a sidecar runs.

Then count the CRDs and find the injection webhook:

```sh
kubectl get crd | grep -c istio.io
kubectl get mutatingwebhookconfigurations | grep istio
```

```text
15
istio-revision-tag-default   4          0s
istio-sidecar-injector       4          20s
```

The CRDs teach the API server what a `VirtualService` is. They are definitions and run nothing. The two mutating webhook configurations tell the API server to call `istiod` when a pod is created, and `istiod` answers by adding the sidecar proxy. `istio-sidecar-injector` holds the webhook entries, and `istio-revision-tag-default` holds the active copy of them for the revision tag `default`. Without them, labelling a namespace does nothing.

---

## Step 4: Switch on injection for `mesh-demo`

```sh
kubectl label namespace mesh-demo istio-injection=enabled
```

```text
namespace/mesh-demo labeled
```

`istio-injection=enabled` is the label that selects the **default** control plane, the one with no revision name. The other choice, `istio.io/rev=<revision>`, picks one named control plane. You do not need it here. Never set both on one namespace: `istio-injection` wins without telling you.

Now check the workload. The command lists the init containers and the containers of each pod, because Istio 1.30 adds the proxy as an init container:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                                     INIT     CONTAINERS
notification-service-76f869bb97-rtj7q   <none>   notification-service
```

No init containers and one container. This is the most important point of the lab: **the label changed nothing for the pod that already exists.** A mutating admission webhook does the injection, and it runs only when a pod is *created*. This pod was created before the webhook applied to its namespace, and admission cannot rewrite an object that is already stored.

---

## Step 5: Create the workload's pod again

```sh
kubectl -n mesh-demo rollout restart deployment notification-service
kubectl -n mesh-demo rollout status deployment notification-service --timeout=180s
```

```text
deployment.apps/notification-service restarted
deployment "notification-service" successfully rolled out
```

With `rollout restart`, the Deployment controller replaces the pods a few at a time, so the Service stays up. The new pods pass through admission with the label in place.

This is *not* the same as deleting the Deployment and applying a new one. The task says to leave the Deployment and Service otherwise unchanged, and the grader counts the Deployments in the namespace. A second workload fails the check.

Look at the pod again. Right after the rollout, the old pod can still be listed for a few seconds while it shuts down; run the command again if you see two pods:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                                     INIT                     CONTAINERS
notification-service-57c79b877b-vw52t   istio-init,istio-proxy   notification-service
```

The new pod has two init containers that the Deployment's template does not define. The webhook wrote them into the pod spec between `kubectl` sending it and the API server storing it. `istio-init` sets up the traffic redirection and exits. `istio-proxy` is the sidecar proxy. It runs as a **native sidecar**: an init container with `restartPolicy: Always`, which Kubernetes starts before the application container and keeps running beside it. That is why it is listed under `INIT` and not under `CONTAINERS`.

---

## Step 6: Check that the versions agree

```sh
istioctl version
```

```text
client version: 1.30.5
control plane version: 1.30.5
data plane version: 1.30.5 (3 proxies)
```

Three versions are in play: the `istioctl` binary, the `istiod` image, and the proxy image inside each injected pod. **3 proxies** is right, because the two gateways are proxies too.

If the last line had shown two different versions, a workload would still be running an old sidecar and would need a restart.

```sh
istioctl proxy-status
```

```text
NAME                                                   CLUSTER        ISTIOD                      VERSION     SUBSCRIBED TYPES
istio-egressgateway-b7dd4655b-k8pq9.istio-system       Kubernetes     istiod-7dc9684c55-wlgdv     1.30.5      3 (CDS,LDS,EDS)
istio-ingressgateway-7f54444996-trvjm.istio-system     Kubernetes     istiod-7dc9684c55-wlgdv     1.30.5      3 (CDS,LDS,EDS)
notification-service-57c79b877b-vw52t.mesh-demo        Kubernetes     istiod-7dc9684c55-wlgdv     1.30.5      4 (CDS,LDS,EDS,RDS)
```

Every proxy is connected to the same `istiod` pod and runs version `1.30.5`. `SUBSCRIBED TYPES` lists the xDS types each proxy receives from `istiod`: Cluster, Listener, Endpoint and Route Discovery Service (`CDS`, `LDS`, `EDS`, `RDS`). The gateways do not ask for `RDS`, because no `Gateway` resource is attached to them yet, so they have no HTTP routes.

---

## Step 7: Submit

```sh
astrona submit
```

The grader checks that:

- `istiod` and **both** gateways are ready.
- The `networking.istio.io` CRDs and the `istio-sidecar-injector` webhook exist.
- `mesh-demo` carries `istio-injection=enabled`.
- `mesh-demo` holds exactly one Deployment, and its running pod has both `notification-service` and `istio-proxy` and is `Ready`.
- The `notification-service` Service is still there.
- The `istiod` image and the injected proxy image have the same version.

---

## Common mistakes

*   **Installing `default` instead of `demo`.** You get `istiod` and one gateway. The grader looks for the egress gateway, because that is the difference between the two profiles.
*   **Labelling the namespace and stopping.** This is the most common failure in this lab. The running pod keeps one container forever. `rollout restart` is the step that brings in the sidecar.
*   **Deleting and recreating the Deployment instead of restarting it.** It produces an injected pod, but the task says to leave the workload otherwise unchanged, and the grader counts Deployments.
*   **Thinking Istio is broken because `istioctl` is not found.** The PATH change did not survive a new shell. Run `export PATH="$HOME/.local/bin:$PATH"`.
*   **Running a second `istioctl install` with different flags to "add" something.** `istioctl install` makes the cluster match the document you pass, and removes components the new document leaves out. Installing `minimal` on top of `demo` deletes both gateways.
