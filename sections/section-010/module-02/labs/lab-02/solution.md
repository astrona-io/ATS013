# Solution Walkthrough

Follow these steps to remove an Istio install made with Helm, finish the cleanup that `helm uninstall` leaves behind, and bring the workload back out of the mesh.

---

## Step 1: Check the starting state

List the Helm releases and the containers of the workload's pod:

```sh
helm ls -A
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

You should see the three releases `istio-base`, `istiod` and `istio-ingressgateway` with the status `deployed`, and one `notification-service` pod whose containers are `notification-service,istio-proxy`.

Then look at the CRDs (Custom Resource Definitions, which add new object kinds to the Kubernetes API server):

```sh
kubectl get crd
```

The list holds the Istio CRDs, whose names end in `istio.io`, and one more: `backups.platform.example.com`. That CRD belongs to another team, so it must survive the cleanup.

---

## Step 2: Uninstall the three releases

Remove the releases in the reverse order of the install. The gateway depends on `istiod` for its configuration, and `istio-base` holds the definitions the other two used:

```sh
helm uninstall istio-ingressgateway -n istio-ingress
helm uninstall istiod -n istio-system
helm uninstall istio-base -n istio-system
```

```text
release "istio-ingressgateway" uninstalled
release "istiod" uninstalled
release "istio-base" uninstalled
```

`helm uninstall` deletes the objects of the release, including the cluster-wide ones: the sidecar injector webhook, the validating webhook and the cluster roles. Then it deletes the release record, the `sh.helm.release.v1.*` Secrets.

This is why you must not skip this step and only delete the namespaces. Deleting `istio-system` removes the release Secrets and the namespaced objects, but the webhook configurations and cluster roles are not in any namespace. They stay, and Helm no longer knows that they exist.

Now check what is left:

```sh
helm ls -A
kubectl get crd | grep -c istio.io
```

```text
NAME    NAMESPACE   REVISION    STATUS  CHART   APP VERSION

15
```

No releases are left, but all fifteen Istio CRDs are still installed. Helm leaves them in place on purpose, because deleting a CRD deletes every object of that kind in the whole cluster.

---

## Step 3: Delete only the Istio CRDs

```sh
kubectl get crd -o name | grep 'istio.io$' | xargs -r kubectl delete
```

The `grep 'istio.io$'` filter keeps every CRD that does not end in `istio.io` out of the delete. Do not use `kubectl delete crd --all`: it also deletes `backups.platform.example.com`, and with it every `Backup` object of the other team.

Then check the result:

```sh
kubectl get crd
```

You should see only `backups.platform.example.com`.

---

## Step 4: Delete the Istio namespaces

```sh
kubectl delete namespace istio-system istio-ingress --ignore-not-found
```

`kubectl delete namespace` waits until each namespace is really gone. When the command returns, `kubectl get namespace istio-system` answers `NotFound`.

---

## Step 5: Remove the injection label

```sh
kubectl label namespace mesh-demo istio-injection-
```

The trailing `-` removes the label. The namespace itself stays. Now check the workload:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

The pod still lists `notification-service,istio-proxy`. Removing the control plane and the label changes nothing for a pod that already runs: the `istio-proxy` container is part of its stored pod spec. That proxy now runs with no control plane to send it configuration and no certificate renewal.

---

## Step 6: Create the workload's pod again

```sh
kubectl -n mesh-demo rollout restart deployment notification-service
kubectl -n mesh-demo rollout status deployment notification-service --timeout=180s
```

```text
deployment.apps/notification-service restarted
deployment "notification-service" successfully rolled out
```

The Deployment controller replaces the pod. The new pod passes through the API server with no injection webhook and no label, so it comes back with only the application container. Do not delete and re-create the Deployment instead: the task says to leave it otherwise unchanged, and the grader counts the Deployments in `mesh-demo`.

The old pod can take a few seconds to finish terminating. Wait until only one pod is listed, then look again:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

The pod now lists only `notification-service`.

---

## Step 7: Submit

```sh
astrona submit
```

The grader checks that:

- No Helm release Secret exists for `istio-base`, `istiod` or `istio-ingressgateway`.
- No Deployment, mutating webhook configuration, validating webhook configuration or cluster role with `istio` in its name is left.
- No CRD whose name ends in `istio.io` is left, and `backups.platform.example.com` still exists.
- The namespaces `istio-system` and `istio-ingress` are gone.
- `mesh-demo` carries neither `istio-injection` nor `istio.io/rev`.
- `mesh-demo` holds exactly one Deployment and the `notification-service` Service, and its running pod has no `istio-proxy` container and is `Ready`.

---

## Common mistakes

*   **Deleting the namespaces instead of uninstalling.** The release Secrets disappear with `istio-system`, but the webhook configurations and cluster roles stay in the cluster.
*   **Stopping after `helm uninstall`.** The Istio CRDs stay. The next install starts on top of old definitions.
*   **Deleting every CRD.** `kubectl delete crd --all` also deletes `backups.platform.example.com`. Filter on the `istio.io` suffix.
*   **Removing the label and stopping.** The running pod keeps its sidecar until it is created again.
*   **Deleting and re-creating the Deployment.** It gives a pod without a sidecar, but the task says to restart the existing workload, and the grader counts Deployments.
