# Solution Walkthrough

Follow these steps to remove an Istio install made with Helm, finish the cleanup that `helm uninstall` leaves behind, and bring the workload back out of the mesh.

---

## Step 1: Check the starting state

List the Helm releases and the init containers and containers of the workload's pod:

```sh
helm ls -A
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name'
```

```text
NAME                	NAMESPACE    	REVISION	UPDATED                              	STATUS  	CHART         	APP VERSION
istio-base          	istio-system 	1       	2026-10-10 01:43:40.458643 +0200 CEST	deployed	base-1.30.5   	1.30.5     
istio-ingressgateway	istio-ingress	1       	2026-10-10 01:43:51.618714 +0200 CEST	deployed	gateway-1.30.5	1.30.5     
istiod              	istio-system 	1       	2026-10-10 01:43:41.092726 +0200 CEST	deployed	istiod-1.30.5 	1.30.5     
POD                                     INIT                     CONTAINERS
notification-service-76f869bb97-929c7   istio-init,istio-proxy   notification-service
```

The three releases `istio-base`, `istiod` and `istio-ingressgateway` have the status `deployed`. The `notification-service` pod has the sidecar proxy: `istio-proxy` runs as a native sidecar, an init container with `restartPolicy: Always`, next to `istio-init`, which set up the traffic redirection and exited.

Then look at the CRDs (Custom Resource Definitions, which add new object kinds to the Kubernetes API server):

```sh
kubectl get crd
```

```text
NAME                                       SCOPE        VERSIONS                       CREATED AT
authorizationpolicies.security.istio.io    Namespaced   v1(storage),v1beta1            2026-10-09T23:43:40Z
backups.platform.example.com               Namespaced   v1(storage)                    2026-10-09T23:43:58Z
destinationrules.networking.istio.io       Namespaced   v1(storage),v1alpha3,v1beta1   2026-10-09T23:43:40Z
envoyfilters.networking.istio.io           Namespaced   v1alpha3(storage)              2026-10-09T23:43:40Z
gateways.networking.istio.io               Namespaced   v1(storage),v1alpha3,v1beta1   2026-10-09T23:43:40Z
peerauthentications.security.istio.io      Namespaced   v1(storage),v1beta1            2026-10-09T23:43:40Z
proxyconfigs.networking.istio.io           Namespaced   v1beta1(storage)               2026-10-09T23:43:40Z
requestauthentications.security.istio.io   Namespaced   v1(storage),v1beta1            2026-10-09T23:43:40Z
serviceentries.networking.istio.io         Namespaced   v1(storage),v1alpha3,v1beta1   2026-10-09T23:43:40Z
sidecars.networking.istio.io               Namespaced   v1(storage),v1alpha3,v1beta1   2026-10-09T23:43:40Z
telemetries.telemetry.istio.io             Namespaced   v1,v1alpha1(storage)           2026-10-09T23:43:40Z
trafficextensions.extensions.istio.io      Namespaced   v1alpha1(storage)              2026-10-09T23:43:40Z
virtualservices.networking.istio.io        Namespaced   v1(storage),v1alpha3,v1beta1   2026-10-09T23:43:40Z
wasmplugins.extensions.istio.io            Namespaced   v1alpha1(storage)              2026-10-09T23:43:40Z
workloadentries.networking.istio.io        Namespaced   v1(storage),v1alpha3,v1beta1   2026-10-09T23:43:40Z
workloadgroups.networking.istio.io         Namespaced   v1(storage),v1alpha3,v1beta1   2026-10-09T23:43:40Z
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

The output looks like this (shortened: the list of kept CRDs has fifteen lines):

```text
release "istio-ingressgateway" uninstalled
release "istiod" uninstalled
These resources were kept due to the resource policy:
[CustomResourceDefinition] trafficextensions.extensions.istio.io
[CustomResourceDefinition] workloadentries.networking.istio.io
...
[CustomResourceDefinition] virtualservices.networking.istio.io

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
NAME	NAMESPACE	REVISION	UPDATED	STATUS	CHART	APP VERSION
15
```

No releases are left, but all fifteen Istio CRDs are still installed. Helm said so when it uninstalled `istio-base`: each Istio CRD carries the annotation `helm.sh/resource-policy: keep`. Helm leaves them in place on purpose, because deleting a CRD deletes every object of that kind in the whole cluster.

---

## Step 3: Delete only the Istio CRDs

```sh
kubectl get crd -o name | grep 'istio.io$' | xargs -r kubectl delete
```

The output looks like this (shortened: there is one line for each of the fifteen CRDs):

```text
customresourcedefinition.apiextensions.k8s.io "authorizationpolicies.security.istio.io" deleted
customresourcedefinition.apiextensions.k8s.io "destinationrules.networking.istio.io" deleted
...
customresourcedefinition.apiextensions.k8s.io "workloadgroups.networking.istio.io" deleted
```

The `grep 'istio.io$'` filter keeps every CRD that does not end in `istio.io` out of the delete. Do not use `kubectl delete crd --all`: it also deletes `backups.platform.example.com`, and with it every `Backup` object of the other team.

Then check the result:

```sh
kubectl get crd
```

```text
NAME                           SCOPE        VERSIONS      CREATED AT
backups.platform.example.com   Namespaced   v1(storage)   2026-10-09T23:43:58Z
```

Only `backups.platform.example.com` is left.

---

## Step 4: Delete the Istio namespaces

```sh
kubectl delete namespace istio-system istio-ingress --ignore-not-found
```

```text
namespace "istio-system" deleted
namespace "istio-ingress" deleted
```

`kubectl delete namespace` waits until each namespace is really gone. When the command returns, `kubectl get namespace istio-system` answers `Error from server (NotFound): namespaces "istio-system" not found`.

---

## Step 5: Remove the injection label

```sh
kubectl label namespace mesh-demo istio-injection-
```

```text
namespace/mesh-demo unlabeled
```

The trailing `-` removes the label. The namespace itself stays. Now check the workload:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                                     INIT                     CONTAINERS
notification-service-76f869bb97-929c7   istio-init,istio-proxy   notification-service
```

The pod still lists `istio-proxy`. Removing the control plane and the label changes nothing for a pod that already runs: the `istio-proxy` container is part of its stored pod spec. That proxy now runs with no control plane to send it configuration and no certificate renewal.

---

## Step 6: Create the workload's pod again

```sh
kubectl -n mesh-demo rollout restart deployment notification-service
kubectl -n mesh-demo rollout status deployment notification-service --timeout=180s
```

```text
deployment.apps/notification-service restarted
Waiting for deployment "notification-service" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "notification-service" rollout to finish: 1 old replicas are pending termination...
deployment "notification-service" successfully rolled out
```

The Deployment controller replaces the pod. The new pod passes through the API server with no injection webhook and no label, so it comes back with only the application container. Do not delete and re-create the Deployment instead: the task says to leave it otherwise unchanged, and the grader counts the Deployments in `mesh-demo`.

The old pod can take a few seconds to finish terminating. Wait until only one pod is listed, then look again:

```sh
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name'
```

```text
POD                                     INIT     CONTAINERS
notification-service-7d46bc6b75-m49bv   <none>   notification-service
```

The new pod has no init containers and only the `notification-service` container.

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
