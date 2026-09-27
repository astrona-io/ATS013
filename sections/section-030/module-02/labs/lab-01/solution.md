# Solution Walkthrough

Follow these steps to stand up a second control plane, put the namespace behind a tag, and move the workload across.

---

## Step 1: Confirm the Starting State

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

One `istiod` with no suffix — that is "the default revision". One injection webhook, matching `istio-injection=enabled`.

---

## Step 2: Install the Canary Control Plane

```sh
istioctl-1.30.5 install --set profile=minimal --set revision=1-30-5 -y
```

```text
✔ Istio core installed
✔ Istiod installed
✔ Installation complete
```

Two deliberate choices in that line:

*   **`--set revision=1-30-5`** suffixes every namespaced object the install owns: `istiod-1-30-5`, its Service, and a webhook `istio-sidecar-injector-1-30-5`. Names do not collide, and Istio's reconciliation is scoped by the `istio.io/rev` ownership label, so this install cannot see or prune the default revision's objects. That scoping *is* the canary mechanism.
*   **`--set profile=minimal`** installs `istiod` and nothing else. A canary needs a second control plane, not a second copy of the gateways — a full profile would create gateway Deployments contending for the same names. Gateways are migrated separately, once the control plane is proven.

Note the name is `1-30-5`, not `1.30.5`. Revision names become Kubernetes object names, so they must be valid DNS labels: no dots.

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

## Step 3: Confirm Nothing Moved

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

`AGE` predates the install, `RESTARTS` is 0, and the `ISTIOD` column still names the **old** control plane pod. Installing a revision is completely non-disruptive — which is the property that makes canary upgrades safe to start.

---

## Step 4: Create the Tag

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

A tag is an **alias**. Mechanically it is another mutating webhook configuration — `istio-revision-tag-prod` — whose selector matches `istio.io/rev=prod` and whose backend is the tagged revision's `istiod` Service.

The reason to bother: without a tag, every future upgrade means relabelling every meshed namespace, and every rollback means relabelling them all back. With a tag, namespaces are labelled once and the upgrade is a single `tag set`.

---

## Step 5: Move the Namespace

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

**Remove the old label first.** `istio-injection` and `istio.io/rev` are mutually exclusive in effect: with both present, `istio-injection` wins and the revision label is ignored — silently, leaving the workload on the control plane you were trying to move away from.

That is not arbitrary logic inside Istio. The default webhook's selector requires `istio-injection: enabled`; the revisioned webhook's selector requires `istio.io/rev` **and** that `istio-injection` is absent. A namespace with both satisfies only the first.

---

## Step 6: Restart the Workload

```sh
kubectl -n canary-demo rollout restart deployment notification-service-v1
kubectl -n canary-demo rollout status deployment notification-service-v1 --timeout=180s
```

This is the step that actually performs the upgrade for the workload. Steps 2 through 5 changed which webhook *would* fire; only a new pod goes through admission.

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

The `ISTIOD` column names the canary, the proxy image is 1.30.5, and the pod carries `istio.io/rev=1-30-5` — the resolved revision, not the tag. That last label is the proof the tag pointed where you meant it to.

---

## Step 7: Submit

```sh
astrona submit
```

The grader checks that **both** control planes are ready, that `istiod-1-30-5` is running 1.30.5, that the canary installed no gateways, that a `prod` tag webhook exists, that `canary-demo` carries `istio.io/rev=prod` and not `istio-injection`, and that the single Deployment's pod is on the 1.30.5 proxy reporting revision `1-30-5`.

---

## Try the Rollback

Not graded, and the fastest way to feel why tags are worth the extra concept:

```sh
istioctl tag set prod --revision default --overwrite -y
kubectl -n canary-demo rollout restart deployment notification-service-v1
```

Two commands, no namespace edits, and the workload is back on the old control plane. Point it forward again before submitting.

---

## Common Mistakes

*   **Leaving `istio-injection=enabled` in place.** With both labels present, the revision label is ignored and the workload never moves. The grader names this case specifically.
*   **Labelling the namespace with the raw revision instead of the tag.** `istio.io/rev=1-30-5` works, and it is exactly the thing that does not scale. The task asks for the tag.
*   **Forgetting the restart.** Installing a revision, creating a tag and relabelling a namespace are all no-ops for running pods.
*   **Installing the canary with the `demo` profile.** Two sets of gateways contend for the same names. Use `minimal`.
*   **Using a dotted revision name.** `1.30.5` is not a valid DNS label.
*   **Installing the revision with the old binary.** `istioctl install --set revision=1-30-5` with the 1.29.8 binary creates a revision named `1-30-5` running **1.29.8**. The name is just a string; the version comes from the binary.
*   **Uninstalling the old control plane to "finish".** The task requires it still running. Retiring it comes after every workload has moved — and it is the capstone's job.
