# Solution Walkthrough

Follow these steps to install the control plane, bring the existing workload into the mesh, and prove the versions line up.

---

## Step 1: Check the Starting State

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

`x` is short for `experimental`. `precheck` is read-only — it asks whether *this cluster* can accept Istio, looking at the Kubernetes version, leftover CRDs, and conflicting webhooks. It is a statement about the cluster, not about your configuration.

---

## Step 2: Install the Control Plane

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

`-y` skips the confirmation prompt. The command blocks until the components report ready, so when it returns the control plane really is up.

Read the summary carefully — those four ticks are the profile's component list. **`demo` is the profile that installs both gateways**; `default` installs only the ingress gateway and `minimal` installs neither. If your summary is missing "Egress gateways installed", you installed the wrong profile.

Remember that `istioctl install` renders the profile into plain Kubernetes manifests on your machine and applies them. There is no operator pod in the cluster afterwards reconciling anything.

---

## Step 3: Confirm What the Install Created

```sh
kubectl -n istio-system get deploy
```

```text
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
istio-egressgateway    1/1     1            1           50s
istio-ingressgateway   1/1     1            1           50s
istiod                 1/1     1            1           63s
```

Three Deployments: the control plane and both gateways. A gateway is not a special component — it is an ordinary Deployment running the same Envoy image a sidecar runs.

```sh
kubectl get crd | grep -c istio.io
kubectl get mutatingwebhookconfigurations | grep istio
```

```text
15
istio-revision-tag-default       ...   63s
istio-sidecar-injector           ...   63s
```

The CRDs teach the API server what a `VirtualService` is; they are definitions and run nothing. The `istio-sidecar-injector` webhook is what will do the injection in the next step — without it, labelling a namespace achieves nothing.

---

## Step 4: Enable Injection on `mesh-demo`

```sh
kubectl label namespace mesh-demo istio-injection=enabled
```

```text
namespace/mesh-demo labeled
```

`istio-injection=enabled` is the label that selects the **default**, unrevisioned control plane. (The other option, `istio.io/rev=<revision>`, picks a specific revision — that matters in section 030, not here. Never set both on one namespace: `istio-injection` wins silently.)

Now check the workload:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                                     CONTAINERS
notification-service-6c8f9d7b5c-t7wqx   notification-service
```

Still one container. This is the single most important thing in the lab: **the label changed nothing for the pod that already exists.** Injection is done by a mutating admission webhook that runs when a pod is *created*. This pod was admitted before the webhook applied to its namespace, and admission cannot retroactively rewrite a stored object.

---

## Step 5: Recreate the Workload

```sh
kubectl -n mesh-demo rollout restart deployment notification-service
kubectl -n mesh-demo rollout status deployment notification-service --timeout=180s
```

```text
deployment.apps/notification-service restarted
deployment "notification-service" successfully rolled out
```

`rollout restart` replaces the pods through the Deployment controller, gradually, so the Service stays up. The new pods go through admission with the label in place.

Note what this is *not*: deleting the Deployment and applying a new one. The task says to leave the Deployment and Service otherwise unchanged, and the grader counts Deployments in the namespace — a second workload is a failure, not a shortcut.

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                                     CONTAINERS
notification-service-7d4b9f6a21-k2vnm   notification-service,istio-proxy
```

Two containers now, from a Deployment whose template defines one. The second was written into the pod spec by the webhook between `kubectl` submitting it and the API server storing it.

---

## Step 6: Verify the Versions Agree

```sh
istioctl version
```

```text
client version: 1.30.5
control plane version: 1.30.5
data plane version: 1.30.5 (3 proxies)
```

Three versions in play: the `istioctl` binary, the `istiod` image, and the proxy image inside each injected pod. `data plane version` counting **3 proxies** is right — the two gateways are proxies too.

If that last line had shown two different versions, it would mean a workload was still running an old sidecar and needed restarting.

```sh
istioctl proxy-status
```

```text
NAME                                        CLUSTER      CDS      LDS      EDS      RDS        ISTIOD
istio-egressgateway-...istio-system         Kubernetes   SYNCED   SYNCED   SYNCED   NOT SENT   istiod-...
istio-ingressgateway-...istio-system        Kubernetes   SYNCED   SYNCED   SYNCED   NOT SENT   istiod-...
notification-service-...mesh-demo           Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED     istiod-...
```

`CDS`, `LDS`, `EDS` and `RDS` are Envoy's xDS resource types — Cluster, Listener, Endpoint and Route Discovery Service. `SYNCED` means the proxy acknowledged the current configuration. `NOT SENT` on the gateways' `RDS` is normal: there is no `Gateway` resource attached yet, so there are no routes to send.

---

## Step 7: Submit

```sh
astrona submit
```

The grader checks that `istiod` and **both** gateways are ready, that the CRDs and the injector webhook exist, that `mesh-demo` carries `istio-injection=enabled`, that its single Deployment is running a pod with both `notification-service` and `istio-proxy`, that the Service is still there, and that the control plane and proxy images are the same version.

---

## Common Mistakes

*   **Installing `default` instead of `demo`.** You get `istiod` and one gateway. The grader looks for the egress gateway specifically, because that pairing is the difference between the two profiles.
*   **Labelling the namespace and stopping.** The most common failure in this lab. The running pod keeps one container forever; `rollout restart` is the step that performs the injection.
*   **Deleting and recreating the Deployment instead of restarting it.** It produces an injected pod, but the task says to leave the workload otherwise unchanged and the grader counts Deployments.
*   **Assuming `istioctl version` failing means Istio is broken.** If `istioctl` is not found, the PATH export did not survive a new shell — run `export PATH="$HOME/.local/bin:$PATH"`.
*   **Running a second `istioctl install` with different flags to "add" something.** `istioctl install` reconciles the cluster to the document you pass; components the new document omits are removed. Installing `minimal` on top of `demo` deletes both gateways.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [istioctl installation](https://istio.io/v1.30/docs/setup/install/istioctl/) — `istioctl install`, `--set`, and what the command actually applies
- [Install with Helm](https://istio.io/v1.30/docs/setup/install/helm/) — the charts, their values, and install ordering
- [Configuration profiles](https://istio.io/v1.30/docs/setup/additional-setup/config-profiles/) — what each built-in profile turns on
- [Canary upgrades](https://istio.io/v1.30/docs/setup/upgrade/canary/) — revisions, revision labels and moving workloads between control planes
- [Sidecar injection](https://istio.io/v1.30/docs/setup/additional-setup/sidecar-injection/) — the namespace label, the pod annotation, and when injection happens
- [Diagnostic tools](https://istio.io/v1.30/docs/ops/diagnostic-tools/proxy-cmd/) — `proxy-status` and `proxy-config` in full
- [istioctl command reference](https://istio.io/v1.30/docs/reference/commands/istioctl/) — every subcommand and flag
- [Installing gateways](https://istio.io/v1.30/docs/setup/additional-setup/gateway/) — deploying gateways separately from the control plane
