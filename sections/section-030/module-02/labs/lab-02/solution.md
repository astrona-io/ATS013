# Solution Walkthrough

Follow these steps to find the namespace that still depends on the old control plane, move it onto the `prod` revision tag, and then remove the default revision by name. The order matters: every workload moves first, and the old control plane goes last.

---

## Step 1: Find what still uses the old control plane

List every proxy and the `istiod` pod it is connected to:

```sh
istioctl-1.30.5 proxy-status
```

Look at the `ISTIOD` column. The `notification-service-v1` pod in `canary-demo` names an `istiod-1-30-5-...` pod. The `tester` pod in `canary-legacy` names the `istiod` pod with no suffix: the old control plane. The gateways in `istio-system` also name the old control plane, because the `demo` profile installed them with the default revision.

`proxy-status` only finds pods that run. Check the namespace labels as well, because a namespace scaled to zero has no proxies to list:

```sh
kubectl get ns -l istio-injection=enabled
kubectl get ns -l istio.io/rev --show-labels
```

The first command lists `canary-legacy`: it is still labelled for the default control plane. The second command shows that `canary-demo` carries `istio.io/rev=prod`.

Confirm where the `prod` tag points:

```sh
istioctl-1.30.5 tag list
```

The `prod` tag must resolve to revision `1-30-5`, and `canary-demo` follows it.

---

## Step 2: Move `canary-legacy` onto the tag

Remove the old label first, then add the tag label:

```sh
kubectl label namespace canary-legacy istio-injection-
kubectl label namespace canary-legacy istio.io/rev=prod --overwrite
```

The order of the labels matters. The webhook of a revision requires `istio-injection` to be absent, so while both labels are present, `istio-injection` wins and the namespace stays on the default control plane. Use the tag, not the raw revision `1-30-5`: with the tag, the next upgrade is one `tag set` and no namespace label changes.

---

## Step 3: Restart the workload

A label changes nothing for a pod that already runs. Only a new pod passes through admission, the stage where the API server calls the injection webhook. Restart the Deployment and wait for it:

```sh
kubectl -n canary-legacy rollout restart deployment tester
kubectl -n canary-legacy rollout status deployment tester --timeout=180s
```

Then check the proxy image of the new pod:

```sh
kubectl -n canary-legacy get pod -l app=tester \
  -o jsonpath='{.items[0].spec.containers[?(@.name=="istio-proxy")].image}{"\n"}'
```

The image must end in `1.30.5`. Run `istioctl-1.30.5 proxy-status` again: the `tester` pod now names an `istiod-1-30-5-...` pod, and only the gateways still name the old one.

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

`--revision default` removes only the objects owned by the default revision: the `istiod` Deployment, its Service, its injection webhook and, in this cluster, the gateways the `demo` profile installed with it. Revision `1-30-5` and the shared CRDs stay.

Do **not** use `istioctl uninstall --purge`. It removes every revision, including `istiod-1-30-5`, and all the CRDs.

Then check the control plane:

```sh
kubectl -n istio-system get deploy
kubectl get crd virtualservices.networking.istio.io
```

`istiod` is gone, `istiod-1-30-5` is still ready, and the CRD still exists.

---

## Step 6: Prove that traffic still flows

Send a request from the `tester` pod to the Service in `canary-demo`:

```sh
kubectl -n canary-legacy exec deploy/tester -c tester -- \
  curl -s -o /dev/null -w '%{http_code}\n' http://notification-service.canary-demo
```

The command prints `200`: both sidecar proxies now get their configuration and certificates from `istiod-1-30-5`.

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
