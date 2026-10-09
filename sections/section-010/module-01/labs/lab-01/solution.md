# Solution Walkthrough

Follow these steps to install the Istio control plane (`istiod`), bring the existing workload into the mesh, and prove that the versions match.

---

## Step 1: Check the starting state

Confirm the cluster really is clean before you change anything. Both of these commands are *expected* to fail:

```sh
kubectl get ns istio-system
kubectl api-resources --api-group=networking.istio.io
```

```text
Error from server (NotFound): namespaces "istio-system" not found
error: unable to retrieve the complete list of server APIs: networking.istio.io/v1: the server could not find the requested resource
```

Now run the pre-install check:

```sh
istioctl x precheck
```

```text
✔ No issues found when checking the cluster. Istio is safe to install or upgrade!
```

`x` is short for `experimental`. `precheck` only reads. It asks whether *this cluster* can accept Istio: it looks at the Kubernetes version, leftover CRDs and webhooks that would get in the way. It is a statement about the cluster, not about your configuration.

---

## Step 2: Install the control plane

```sh
istioctl install --set profile=demo -y
```

```text
✔ Istio core installed
✔ Istiod installed
✔ Egress gateways installed
✔ Ingress gateways installed
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
istio-egressgateway    1/1     1            1           50s
istio-ingressgateway   1/1     1            1           50s
istiod                 1/1     1            1           63s
```

Three Deployments: the control plane and both gateways. A gateway is not a special component. It is an ordinary Deployment running the same Envoy image a sidecar runs.

Then count the CRDs and find the injection webhook:

```sh
kubectl get crd | grep -c istio.io
kubectl get mutatingwebhookconfigurations | grep istio
```

```text
15
istio-revision-tag-default       ...   63s
istio-sidecar-injector           ...   63s
```

The CRDs teach the API server what a `VirtualService` is. They are definitions and run nothing. The API server calls the `istio-sidecar-injector` mutating webhook when a pod is created, and `istiod` answers by adding the sidecar proxy. Without it, labelling a namespace does nothing.

---

## Step 4: Switch on injection for `mesh-demo`

```sh
kubectl label namespace mesh-demo istio-injection=enabled
```

```text
namespace/mesh-demo labeled
```

`istio-injection=enabled` is the label that selects the **default** control plane, the one with no revision name. The other choice, `istio.io/rev=<revision>`, picks one named control plane. You do not need it here. Never set both on one namespace: `istio-injection` wins without telling you.

Now check the workload:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                                     CONTAINERS
notification-service-6c8f9d7b5c-t7wqx   notification-service
```

Still one container. This is the most important point of the lab: **the label changed nothing for the pod that already exists.** A mutating admission webhook does the injection, and it runs only when a pod is *created*. This pod was created before the webhook applied to its namespace, and admission cannot rewrite an object that is already stored.

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

Look at the pod again:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                                     CONTAINERS
notification-service-7d4b9f6a21-k2vnm   notification-service,istio-proxy
```

Two containers now, from a Deployment whose template defines one. The webhook wrote the second one into the pod spec between `kubectl` sending it and the API server storing it.

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
NAME                                        CLUSTER      CDS      LDS      EDS      RDS        ISTIOD
istio-egressgateway-...istio-system         Kubernetes   SYNCED   SYNCED   SYNCED   NOT SENT   istiod-...
istio-ingressgateway-...istio-system        Kubernetes   SYNCED   SYNCED   SYNCED   NOT SENT   istiod-...
notification-service-...mesh-demo           Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED     istiod-...
```

`CDS`, `LDS`, `EDS` and `RDS` are the four main xDS types `istiod` sends to each proxy: Cluster, Listener, Endpoint and Route Discovery Service. `SYNCED` means the proxy accepted the current configuration. `NOT SENT` under the gateways' `RDS` is normal: no `Gateway` resource is attached yet, so there are no routes to send.

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
