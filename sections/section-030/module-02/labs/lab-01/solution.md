# Solution Walkthrough

Follow these steps to install a second control plane (`istiod`) as a revision, put it behind the revision tag `prod`, and move `canary-demo` and its workload onto it through the tag. The old control plane keeps running the whole time.

---

## Step 1: Confirm the starting state

List the control plane pods, the namespace labels and the versions:

```sh
kubectl -n istio-system get pods -l app=istiod
kubectl get ns canary-demo --show-labels
istioctl version
```

```text
NAME                      READY   STATUS    RESTARTS   AGE
istiod-77d5f6c8b9-qr4tz   1/1     Running   0          4m

NAME          STATUS   AGE   LABELS
canary-demo   Active   4m    istio-injection=enabled,kubernetes.io/metadata.name=canary-demo

client version: 1.29.8
control plane version: 1.29.8
data plane version: 1.29.8 (3 proxies)
```

One `istiod` with no suffix: that is "the default revision". Its injection webhook, the mutating admission webhook that adds the sidecar proxy to new pods, matches namespaces labelled `istio-injection=enabled`.

---

## Step 2: Install the canary control plane

Use the 1.30.5 binary, the `minimal` profile and the revision name `1-30-5`:

```sh
istioctl-1.30.5 install --set profile=minimal --set revision=1-30-5 -y
```

```text
✔ Istio core installed
✔ Istiod installed
✔ Installation complete
```

That line makes two choices on purpose:

*   **`--set revision=1-30-5`** adds the suffix to every namespaced object the install owns: `istiod-1-30-5`, its Service, and a webhook `istio-sidecar-injector-1-30-5`. The names do not collide. The install only manages objects with its own `istio.io/rev` ownership label, so it cannot see or remove the objects of the default revision. That separation is what makes a canary upgrade possible.
*   **`--set profile=minimal`** installs `istiod` and nothing else. A canary needs a second control plane, not a second set of gateways. A full profile would create gateway Deployments that compete for the same names. Gateways move separately, once the control plane has proved itself.

The name is `1-30-5`, not `1.30.5`. Revision names become Kubernetes object names, so they must be valid DNS labels: no dots.

Check the control plane pods and webhooks:

```sh
kubectl -n istio-system get pods -l app=istiod
kubectl get mutatingwebhookconfigurations | grep istio
```

```text
NAME                             READY   STATUS    RESTARTS   AGE
istiod-1-30-5-6b9c8f7d4b-xk2p9   1/1     Running   0          40s
istiod-77d5f6c8b9-qr4tz          1/1     Running   0          9m

istio-revision-tag-default            ...   9m
istio-sidecar-injector                ...   9m
istio-sidecar-injector-1-30-5         ...   40s
```

Two control planes, two webhooks, both healthy.

---

## Step 3: Confirm nothing moved

List the workload's pod and its proxy status:

```sh
kubectl -n canary-demo get pods
istioctl proxy-status | grep -E 'NAME|canary-demo'
```

```text
NAME                                       READY   STATUS    RESTARTS   AGE
notification-service-v1-5d9f8b7c6d-p2mzq   2/2     Running   0          10m

NAME                                     CLUSTER      CDS      LDS      EDS      RDS      ISTIOD
notification-service-v1-...canary-demo   Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED   istiod-77d5f6c8b9-qr4tz
```

`AGE` is older than the install, `RESTARTS` is 0, and the `ISTIOD` column still names the **old** control plane pod. Installing a revision disturbs nothing, and that is what makes a canary upgrade safe to start.

---

## Step 4: Create the tag

Create `prod` for revision `1-30-5`, then list the tags:

```sh
istioctl-1.30.5 tag set prod --revision 1-30-5 -y
istioctl-1.30.5 tag list
```

```text
✔ Revision tag "prod" created, referencing revision "1-30-5".

TAG      REVISION   NAMESPACES
default  default
prod     1-30-5
```

A revision tag is a second name that points at one revision. Underneath, it is another mutating webhook configuration, `istio-revision-tag-prod`. Its selector matches `istio.io/rev=prod`, and it sends injection requests to the `istiod` Service of the tagged revision.

A tag saves work later. Without a tag, every future upgrade means relabelling every namespace in the mesh, and every rollback means relabelling them all back. With a tag, you label the namespaces once, and the upgrade is a single `tag set`.

---

## Step 5: Move the namespace

Remove the old label, add the tag label, and check the result:

```sh
kubectl label namespace canary-demo istio-injection-
kubectl label namespace canary-demo istio.io/rev=prod --overwrite
kubectl get ns canary-demo --show-labels
```

```text
namespace/canary-demo unlabeled
namespace/canary-demo labeled

NAME          STATUS   AGE   LABELS
canary-demo   Active   12m   istio.io/rev=prod,kubernetes.io/metadata.name=canary-demo
```

**Remove the old label first.** In effect, `istio-injection` and `istio.io/rev` rule each other out. With both present, `istio-injection` wins and the revision label is ignored. Nothing warns you, and the workload stays on the control plane you were trying to move away from.

The rule comes from the webhook selectors. The default webhook's selector requires `istio-injection: enabled`. The revision webhook's selector requires `istio.io/rev` **and** that `istio-injection` is absent. A namespace with both labels only satisfies the first.

---

## Step 6: Restart the workload

Restart the Deployment and wait for it:

```sh
kubectl -n canary-demo rollout restart deployment notification-service-v1
kubectl -n canary-demo rollout status deployment notification-service-v1 --timeout=180s
```

This step performs the upgrade for the workload. Steps 2 to 5 changed which webhook the API server *would* call. Only a new pod goes through admission, so only a new pod is injected by the canary control plane.

Check the proxy status, the proxy image and the revision of the new pod:

```sh
istioctl-1.30.5 proxy-status | grep -E 'NAME|canary-demo'
kubectl -n canary-demo get pod -l app=notification-service \
  -o jsonpath='{.items[0].spec.containers[?(@.name=="istio-proxy")].image}{"\n"}'
kubectl -n canary-demo get pod -l app=notification-service \
  -o jsonpath='{.items[0].metadata.labels.istio\.io/rev}{"\n"}'
```

```text
NAME                                     CLUSTER      CDS      LDS      EDS      RDS      ISTIOD
notification-service-v1-...canary-demo   Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED   istiod-1-30-5-6b9c8f7d4b-xk2p9

docker.io/istio/proxyv2:1.30.5
1-30-5
```

The `ISTIOD` column of `istioctl proxy-status` names the canary `istiod` pod, the proxy image is 1.30.5, and the pod records `1-30-5`: the revision the tag resolved to, not the tag itself. That last value proves the tag pointed where you meant. The grader reads it from the pod's `istio.io/rev` annotation first and falls back to the label, because Istio 1.30 records it as an annotation.

---

## Step 7: Submit

Send the lab for grading:

```sh
astrona submit
```

The grader checks that **both** control planes are ready, that `istiod-1-30-5` runs 1.30.5, and that the canary installed no gateways. It checks that a `prod` tag webhook exists, and that `canary-demo` carries `istio.io/rev=prod` and not `istio-injection`. Finally it checks that the single Deployment's pod runs the 1.30.5 proxy and reports revision `1-30-5`.

---

## Try the rollback

This is not graded, but it shows in two commands why a tag is worth the extra step:

```sh
istioctl tag set prod --revision default --overwrite -y
kubectl -n canary-demo rollout restart deployment notification-service-v1
```

Two commands, no namespace edits, and the workload is back on the old control plane. Point the tag forward again and restart before you submit.

---

## Common mistakes

*   **Leaving `istio-injection=enabled` in place.** With both labels present, the revision label is ignored and the workload never moves. The grader names this case.
*   **Labelling the namespace with the raw revision instead of the tag.** `istio.io/rev=1-30-5` works, and it is exactly the thing that does not scale. The task asks for the tag.
*   **Forgetting the restart.** Installing a revision, creating a tag and relabelling a namespace change nothing for running pods.
*   **Installing the canary with the `demo` profile.** Two sets of gateways compete for the same names. Use `minimal`.
*   **Using a dotted revision name.** `1.30.5` is not a valid DNS label.
*   **Installing the revision with the old binary.** `istioctl install --set revision=1-30-5` with the 1.29.8 binary creates a revision named `1-30-5` that runs **1.29.8**. The name is just a string; the version comes from the binary.
*   **Uninstalling the old control plane to "finish".** The task requires it to keep running. Retiring it comes after every workload has moved, and this task does not ask for it.
