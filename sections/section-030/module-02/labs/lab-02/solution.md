# Solution Walkthrough

Follow these steps to find the namespace that still depends on the old control plane, move it onto the `prod` revision tag, and then remove the default revision by name. The order matters: every workload moves first, and the old control plane goes last.

---

## Step 1: Find what still uses the old control plane

`istioctl proxy-status` asks one control plane for the proxies connected to it: the default revision, unless you name another one with `--revision`. Ask both:

```sh
istioctl-1.30.5 proxy-status
istioctl-1.30.5 proxy-status --revision 1-30-5
```

```text
NAME                                                   CLUSTER        ISTIOD                      VERSION     SUBSCRIBED TYPES
istio-egressgateway-7b5fc4675c-bz4hk.istio-system      Kubernetes     istiod-68b5bc79c8-gr8st     1.29.8      3 (CDS,LDS,EDS)
istio-ingressgateway-7f57d9869c-zzwzt.istio-system     Kubernetes     istiod-68b5bc79c8-gr8st     1.29.8      3 (CDS,LDS,EDS)
tester-577d497fbd-hhxhq.canary-legacy                  Kubernetes     istiod-68b5bc79c8-gr8st     1.29.8      4 (CDS,LDS,EDS,RDS)
NAME                                                     CLUSTER        ISTIOD                            VERSION     SUBSCRIBED TYPES
notification-service-v1-746cd97ddb-969sr.canary-demo     Kubernetes     istiod-1-30-5-67fd8d4b8-l75fr     1.30.5      4 (CDS,LDS,EDS,RDS)
```

The first list is everything that still depends on the old control plane, the `istiod` pod with no suffix. The `tester` pod in `canary-legacy` is there, with a `1.29.8` proxy. The gateways in `istio-system` are there too, because the `demo` profile installed them with the default revision. The `notification-service-v1` pod in `canary-demo` is only in the second list: it already uses `istiod-1-30-5`.

`proxy-status` only finds pods that run. Check the namespace labels as well, because a namespace scaled to zero has no proxies to list:

```sh
kubectl get ns -l istio-injection=enabled
kubectl get ns -l istio.io/rev --show-labels
```

```text
NAME            STATUS   AGE
canary-legacy   Active   31s
NAME          STATUS   AGE   LABELS
canary-demo   Active   12s   istio.io/rev=prod,kubernetes.io/metadata.name=canary-demo
```

The first command lists `canary-legacy`: it is still labelled for the default control plane. The second command shows that `canary-demo` carries `istio.io/rev=prod`.

Confirm where the `prod` tag points:

```sh
istioctl-1.30.5 tag list
```

```text
TAG     REVISION NAMESPACES
prod    1-30-5   canary-demo
default default  
```

The `prod` tag resolves to revision `1-30-5`, and `canary-demo` follows it.

---

## Step 2: Move `canary-legacy` onto the tag

Remove the old label first, then add the tag label:

```sh
kubectl label namespace canary-legacy istio-injection-
kubectl label namespace canary-legacy istio.io/rev=prod --overwrite
```

```text
namespace/canary-legacy unlabeled
namespace/canary-legacy labeled
```

The order of the labels matters. The webhook of a revision requires `istio-injection` to be absent, so while both labels are present, `istio-injection` wins and the namespace stays on the default control plane. Use the tag, not the raw revision `1-30-5`: with the tag, the next upgrade is one `tag set` and no namespace label changes.

---

## Step 3: Restart the workload

A label changes nothing for a pod that already runs. Only a new pod passes through admission, the stage where the API server calls the injection webhook. Restart the Deployment and wait for it:

```sh
kubectl -n canary-legacy rollout restart deployment tester
kubectl -n canary-legacy rollout status deployment tester --timeout=180s
```

```text
deployment.apps/tester restarted
Waiting for deployment "tester" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "tester" rollout to finish: 1 old replicas are pending termination...
deployment "tester" successfully rolled out
```

The old `tester` pod takes up to 30 seconds to stop. When it is gone, check the proxy image of the new pod and both proxy lists again. Istio runs `istio-proxy` as a native sidecar, an init container with `restartPolicy: Always`, so the image is in `.spec.initContainers`:

```sh
kubectl -n canary-legacy get pod -l app=tester \
  -o jsonpath='{.items[0].spec.initContainers[?(@.name=="istio-proxy")].image}{"\n"}'
istioctl-1.30.5 proxy-status
istioctl-1.30.5 proxy-status --revision 1-30-5
```

```text
registry.istio.io/release/proxyv2:1.30.5
NAME                                                   CLUSTER        ISTIOD                      VERSION     SUBSCRIBED TYPES
istio-egressgateway-7b5fc4675c-bz4hk.istio-system      Kubernetes     istiod-68b5bc79c8-gr8st     1.29.8      3 (CDS,LDS,EDS)
istio-ingressgateway-7f57d9869c-zzwzt.istio-system     Kubernetes     istiod-68b5bc79c8-gr8st     1.29.8      3 (CDS,LDS,EDS)
NAME                                                     CLUSTER        ISTIOD                            VERSION     SUBSCRIBED TYPES
notification-service-v1-746cd97ddb-969sr.canary-demo     Kubernetes     istiod-1-30-5-67fd8d4b8-l75fr     1.30.5      4 (CDS,LDS,EDS,RDS)
tester-5b86549456-6whcg.canary-legacy                    Kubernetes     istiod-1-30-5-67fd8d4b8-l75fr     1.30.5      4 (CDS,LDS,EDS,RDS)
```

The image ends in `1.30.5`, the `tester` pod is now connected to `istiod-1-30-5`, and only the gateways still use the old control plane.

---

## Step 4: Check that nothing is left behind

Repeat the namespace check:

```sh
kubectl get ns -l istio-injection=enabled
```

```text
No resources found
```

No namespace is labelled for the old control plane any more, and every application proxy is connected to `istiod-1-30-5`. This is the evidence you want before you remove anything.

---

## Step 5: Remove the default revision

Remove the old control plane by its revision name:

```sh
istioctl uninstall --revision default -y
```

The output looks like this (shortened: the uninstall prints one `Removed` line for every object it deletes, and only the last ones are shown):

```text
...
  Removed admissionregistration.k8s.io/v1, Kind=MutatingWebhookConfiguration/istio-revision-tag-default..
  Removed admissionregistration.k8s.io/v1, Kind=MutatingWebhookConfiguration/istio-sidecar-injector..
  Removed admissionregistration.k8s.io/v1, Kind=ValidatingWebhookConfiguration/istio-validator-istio-system..
  Removed admissionregistration.k8s.io/v1, Kind=ValidatingWebhookConfiguration/istiod-default-validator..
  Removed rbac.authorization.k8s.io/v1, Kind=ClusterRole/istio-reader-clusterrole-istio-system..
  Removed rbac.authorization.k8s.io/v1, Kind=ClusterRole/istiod-clusterrole-istio-system..
  Removed rbac.authorization.k8s.io/v1, Kind=ClusterRole/istiod-gateway-controller-istio-system..
  Removed rbac.authorization.k8s.io/v1, Kind=ClusterRoleBinding/istio-reader-clusterrole-istio-system..
  Removed rbac.authorization.k8s.io/v1, Kind=ClusterRoleBinding/istiod-clusterrole-istio-system..
  Removed rbac.authorization.k8s.io/v1, Kind=ClusterRoleBinding/istiod-gateway-controller-istio-system..

✔ Uninstall complete
```

`--revision default` removes only the objects owned by the default revision: the `istiod` Deployment, its Service, its injection webhooks (including the `default` tag), and, in this cluster, the gateways the `demo` profile installed with it. Revision `1-30-5` and the shared CRDs stay.

Do **not** use `istioctl uninstall --purge`. It removes every revision, including `istiod-1-30-5`, and all the CRDs.

Then check the control plane:

```sh
kubectl -n istio-system get deploy
kubectl get crd virtualservices.networking.istio.io
```

```text
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
istio-egressgateway    0/1     0            0           80s
istio-ingressgateway   0/1     0            0           80s
istiod-1-30-5          1/1     1            1           61s
NAME                                  SCOPE        VERSIONS                       CREATED AT
virtualservices.networking.istio.io   Namespaced   v1(storage),v1alpha3,v1beta1   2026-10-10T00:47:11Z
```

`istiod` is gone, `istiod-1-30-5` is still ready, and the CRD still exists. The two gateway Deployments show `0/1` while Kubernetes deletes them; a few seconds later they are gone too.

---

## Step 6: Prove that traffic still flows

Send a request from the `tester` pod to the Service in `canary-demo`:

```sh
kubectl -n canary-legacy exec deploy/tester -c tester -- \
  curl -s -o /dev/null -w '%{http_code}\n' http://notification-service.canary-demo
```

```text
200
```

The request succeeds: both sidecar proxies now get their configuration and certificates from `istiod-1-30-5`.

---

## Step 7: Submit

Send the lab for grading:

```sh
astrona submit
```

The grader checks that the `istiod` Deployment is gone, that `istiod-1-30-5`, the `prod` tag webhook and the Istio CRDs still exist, and that no namespace carries `istio-injection=enabled`. It checks that `canary-legacy` carries `istio.io/rev=prod` and holds only the `tester` Deployment. It checks that the `tester` and `notification-service` pods each run a 1.30.5 `istio-proxy`, report revision `1-30-5` and are `Ready`. Finally, it sends a request from `tester` to `notification-service` and expects `200`.

---

## Common mistakes

*   **Uninstalling before moving `canary-legacy`.** The `tester` pod keeps its 1.29.8 proxy and loses its control plane: no configuration updates and no certificate renewal. The grader rejects the old proxy image.
*   **`istioctl uninstall --purge`.** It removes `istiod-1-30-5` and the CRDs too, so the whole mesh loses its control plane.
*   **Removing `istio-injection` without adding `istio.io/rev=prod`.** After the restart, `tester` has no sidecar proxy at all and is no longer in the mesh.
*   **Labelling `canary-legacy` with `istio.io/rev=1-30-5`.** It works today, but the task asks for the tag, so the next upgrade does not need a relabel.
*   **Checking only `proxy-status`.** A namespace scaled to zero has no proxies to list. Check the namespace labels too.
