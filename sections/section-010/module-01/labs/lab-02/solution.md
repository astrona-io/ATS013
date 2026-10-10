# Solution Walkthrough

Follow these steps to remove Istio from the cluster completely, clear what the uninstall leaves behind, and prove that the applications still work without the mesh.

---

## Step 1: Look at the starting state

Before you remove anything, see what is there. List the init containers and the containers of each pod in `mesh-demo`:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                                     INIT                     CONTAINERS
notification-service-76f869bb97-grckj   istio-init,istio-proxy   notification-service
tester-b9794959f-7jfd9                  istio-init,istio-proxy   tester
```

Each of the two pods lists its application container (`notification-service` or `tester`) and two init containers that the injection webhook added when the pod was created. `istio-proxy` is the sidecar proxy: an Envoy container that handles all inbound and outbound traffic of the pod. It runs as a native sidecar, an init container with `restartPolicy: Always`, so it is listed under `INIT`. `istio-init` sets up the traffic redirection and exits.

Then check the namespace label:

```sh
kubectl get ns mesh-demo --show-labels
```

```text
NAME        STATUS   AGE   LABELS
mesh-demo   Active   9s    istio-injection=enabled,kubernetes.io/metadata.name=mesh-demo
```

The `LABELS` column contains `istio-injection=enabled`. This label tells the injection webhook to add a sidecar to every new pod in the namespace.

---

## Step 2: Remove every revision and the CRDs

```sh
istioctl uninstall --purge -y
```

```text
All Istio resources will be pruned from the cluster

  Removed apps/v1, Kind=Deployment/istio-egressgateway.istio-system.
  Removed apps/v1, Kind=Deployment/istio-ingressgateway.istio-system.
...
  Removed apiextensions.k8s.io/v1, Kind=CustomResourceDefinition/workloadgroups.networking.istio.io..

✔ Uninstall complete
```

(The output is shortened: the uninstall prints one `Removed` line for every object it deletes.) `--purge` removes every revision, that is every named control plane installation, together with all cluster-wide Istio resources, CRDs (Custom Resource Definitions) and webhook configurations included. `-y` skips the confirmation question.

The other mode, `istioctl uninstall --revision default`, removes only one control plane and the objects labelled for it. It leaves the CRDs in place, because other revisions might still need them. For a fully clean cluster you need `--purge`. The grader checks the CRDs, so an uninstall without `--purge` fails.

Confirm the CRDs are gone:

```sh
kubectl api-resources --api-group=networking.istio.io
```

```text
NAME   SHORTNAMES   APIVERSION   NAMESPACED   KIND
```

Only the header line is left. This is the same result a cluster that never had Istio gives: the API server no longer knows any resource in the `networking.istio.io` group. If the list still shows one or two resources right after the uninstall, the API server is still removing the CRDs; wait a few seconds and run the command again.

---

## Step 3: Delete the istio-system namespace

`istioctl uninstall` does not delete the `istio-system` namespace, even with `--purge`. Delete it yourself:

```sh
kubectl delete namespace istio-system --ignore-not-found
```

```text
namespace "istio-system" deleted
```

The command waits until the namespace is gone. If you stop it early, the namespace may still show `Terminating` for a short time, and the grader asks you to wait.

---

## Step 4: Remove the injection label

The `istio-injection=enabled` label sits on your own namespace object, which Istio does not own, so the uninstall leaves it in place. With no webhook it does nothing today, but the next Istio install would act on it again. Remove it; the `-` after the label key deletes the label:

```sh
kubectl label namespace mesh-demo istio-injection-
```

```text
namespace/mesh-demo unlabeled
```

Do not set the label to `disabled` instead: the task asks for the label to be removed, and the grader fails on any value.

---

## Step 5: Recreate the pods without sidecars

Check the pods again:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                                     INIT                     CONTAINERS
notification-service-76f869bb97-grckj   istio-init,istio-proxy   notification-service
tester-b9794959f-7jfd9                  istio-init,istio-proxy   tester
```

Both pods still list `istio-proxy`. The webhook added the sidecar when each pod was created, and the container is part of the stored pod spec. The uninstall does not change pods that already run. These proxies now run with no control plane: they get no configuration updates and no new certificates.

The only way to remove a sidecar is to replace the pod. Restart both Deployments; the Deployment controller creates new pods, and with no webhook, the API server stores them without a sidecar:

```sh
kubectl -n mesh-demo rollout restart deployment notification-service tester
kubectl -n mesh-demo rollout status deployment notification-service --timeout=180s
kubectl -n mesh-demo rollout status deployment tester --timeout=180s
```

```text
deployment.apps/notification-service restarted
deployment.apps/tester restarted
Waiting for deployment "notification-service" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "notification-service" rollout to finish: 1 old replicas are pending termination...
deployment "notification-service" successfully rolled out
Waiting for deployment "tester" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "tester" rollout to finish: 1 old replicas are pending termination...
deployment "tester" successfully rolled out
```

Do not delete the Deployments or the namespace to get rid of the sidecars. The task says to keep them, and the grader checks that both Deployments and the Service still exist.

List the containers one more time:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                                     INIT                     CONTAINERS
notification-service-5449659c66-b95b5   <none>                   notification-service
tester-69975dbf66-kxvf5                 <none>                   tester
tester-b9794959f-7jfd9                  istio-init,istio-proxy   tester
```

The new pods list only their application container and no init containers. The old `tester` pod is still listed: it is shutting down, and the `curl` image's `sleep` command does not stop on the termination signal, so Kubernetes waits the full grace period of 30 seconds. Wait half a minute and run the command again:

```text
POD                                     INIT     CONTAINERS
notification-service-5449659c66-b95b5   <none>   notification-service
tester-69975dbf66-kxvf5                 <none>   tester
```

The grader fails while the old pod still exists, so wait for this output before you submit.

---

## Step 6: Prove the applications still work

Send a request from the `tester` pod to the `notification-service` Service and print only the HTTP status code:

```sh
kubectl -n mesh-demo exec deploy/tester -- curl -s -o /dev/null -w '%{http_code}\n' http://notification-service
```

```text
200
```

The request now goes straight from the `tester` container to the `notification-service` pod, with no sidecar proxy on either side.

---

## Step 7: Submit

```sh
astrona submit
```

The grader checks that:

- The `istio-system` namespace is gone, and no `istiod` Deployment exists anywhere in the cluster.
- No CRD whose name ends in `istio.io` remains.
- No mutating or validating webhook configuration with `istio` in its name remains.
- `mesh-demo` has no `istio-injection` label and no `istio.io/rev` label.
- `mesh-demo` holds exactly the two Deployments `notification-service` and `tester`, both ready, and the `notification-service` Service.
- No pod in `mesh-demo` has an `istio-proxy` container.
- A request from `tester` to `http://notification-service` returns `200`.

---

## Common mistakes

*   **Running `istioctl uninstall` without `--purge`.** The CRDs stay, and the next install starts on top of old definitions. The grader looks for any CRD that ends in `istio.io`.
*   **Stopping after the uninstall.** The `istio-system` namespace, the namespace label and the sidecars in the running pods all survive it. A full cleanup takes the uninstall, the namespace delete, the label removal and a restart of the workloads.
*   **Expecting the uninstall to remove the sidecars.** Injection happens once, when a pod is created. Only a new pod comes up without the sidecar.
*   **Deleting the workloads to get rid of the sidecars.** It removes the sidecars, but also the application. Restart the Deployments instead.
*   **Restarting the workloads before the uninstall.** While the webhook still exists and the label is still set, the new pods get a sidecar again. Remove the control plane and the label first, then restart.
