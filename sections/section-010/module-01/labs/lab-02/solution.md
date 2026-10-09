# Solution Walkthrough

Follow these steps to remove Istio from the cluster completely, clear what the uninstall leaves behind, and prove that the applications still work without the mesh.

---

## Step 1: Look at the starting state

Before you remove anything, see what is there. List the containers of each pod in `mesh-demo`:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

Each of the two pods lists two containers: its application container (`notification-service` or `tester`) and `istio-proxy`. The `istio-proxy` container is the sidecar proxy: an Envoy container that the injection webhook added to the pod when the pod was created.

Then check the namespace label:

```sh
kubectl get ns mesh-demo --show-labels
```

The `LABELS` column contains `istio-injection=enabled`. This label tells the injection webhook to add a sidecar to every new pod in the namespace.

---

## Step 2: Remove every revision and the CRDs

```sh
istioctl uninstall --purge -y
```

```text
All Istio resources will be pruned from the cluster
...
```

(The output is shortened.) `--purge` removes every revision, that is every named control plane installation, together with all cluster-wide Istio resources, CRDs (Custom Resource Definitions) and webhook configurations included. `-y` skips the confirmation question.

The other mode, `istioctl uninstall --revision default`, removes only one control plane and the objects labelled for it. It leaves the CRDs in place, because other revisions might still need them. For a fully clean cluster you need `--purge`. The grader checks the CRDs, so an uninstall without `--purge` fails.

Confirm the CRDs are gone:

```sh
kubectl api-resources --api-group=networking.istio.io
```

```text
error: unable to retrieve the complete list of server APIs: networking.istio.io/v1: the server could not find the requested resource
```

This is the same error a cluster that never had Istio gives: the API server no longer knows the `networking.istio.io` group.

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

`kubectl` answers that `mesh-demo` is unlabeled. Do not set the label to `disabled` instead: the task asks for the label to be removed, and the grader fails on any value.

---

## Step 5: Recreate the pods without sidecars

Check the pods again:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

Both pods still list `istio-proxy`. The webhook added the sidecar when each pod was created, and the container is part of the stored pod spec. The uninstall does not change pods that already run. These proxies now run with no control plane: they get no configuration updates and no new certificates.

The only way to remove a sidecar is to replace the pod. Restart both Deployments; the Deployment controller creates new pods, and with no webhook, the API server stores them without a sidecar:

```sh
kubectl -n mesh-demo rollout restart deployment notification-service tester
kubectl -n mesh-demo rollout status deployment notification-service --timeout=180s
kubectl -n mesh-demo rollout status deployment tester --timeout=180s
```

`kubectl` reports that both Deployments were restarted and that each one rolled out successfully.

Do not delete the Deployments or the namespace to get rid of the sidecars. The task says to keep them, and the grader checks that both Deployments and the Service still exist.

List the containers one more time:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

Each pod now lists only its application container. If an old pod with `istio-proxy` still shows as `Terminating`, wait a few seconds and run the command again.

---

## Step 6: Prove the applications still work

Send a request from the `tester` pod to the `notification-service` Service and print only the HTTP status code:

```sh
kubectl -n mesh-demo exec deploy/tester -- curl -s -o /dev/null -w '%{http_code}\n' http://notification-service
```

The command prints `200`. The request now goes straight from the `tester` container to the `notification-service` pod, with no sidecar proxy on either side.

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
