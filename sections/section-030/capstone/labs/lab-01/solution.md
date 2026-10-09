# Solution Walkthrough

Mission debrief, astronaut. Read this only after you have tried the task on your own.

You built a second mission control, gave it the call sign `prod`, pointed two planets at the call sign, relaunched every ship, and only then closed the old mission control.

---

## Step 1: The order is the exercise

There are five operations, and one rule about their order carries the whole point:

```text
  1. install revision 1-30-5          (non-disruptive)
  2. create tag prod -> 1-30-5        (non-disruptive)
  3. relabel both namespaces          (non-disruptive)
  4. restart every workload           ← THIS is the upgrade
  5. retire the default revision      ← only after 4
```

Steps 1 to 3 change nothing for running pods. Step 4 is where workloads really move. Doing step 5 before step 4 leaves pods connected to a control plane that no longer exists. They keep serving on their last orders, but get no updates and cannot renew their workload certificate (their ID badge) when it expires. The failure arrives hours later and looks unrelated.

---

## Step 2: Install the canary revision

Install 1.30.5 as revision `1-30-5` with the `minimal` profile, and list the control plane pods:

```sh
istioctl-1.30.5 install --set profile=minimal --set revision=1-30-5 -y
kubectl -n istio-system get pods -l app=istiod
```

```text
NAME                             READY   STATUS    RESTARTS   AGE
istiod-1-30-5-6b9c8f7d4b-xk2p9   1/1     Running   0          42s
istiod-77d5f6c8b9-qr4tz          1/1     Running   0          8m
```

The revision adds a suffix to every namespaced object the install owns. The install only manages objects with its own `istio.io/rev` ownership label, so it cannot see or remove the default revision's objects. That separation lets two control planes run side by side.

Use the **1.30.5 binary**. `istioctl install --set revision=1-30-5` run with the 1.29.8 binary creates a revision *named* `1-30-5` that runs **1.29.8**. The name is just a string; the version comes from the binary.

---

## Step 3: Create the tag

Create `prod` for revision `1-30-5`, then list the tags:

```sh
istioctl-1.30.5 tag set prod --revision 1-30-5 -y
istioctl-1.30.5 tag list
```

```text
TAG      REVISION   NAMESPACES
default  default
prod     1-30-5
```

The tag is another mutating webhook configuration. Its selector matches `istio.io/rev=prod`, and its backend is the Service of the tagged revision. With two namespaces the saving looks small. With fifty, it is the difference between one command and fifty chances to miss one.

---

## Step 4: Move both namespaces

For each namespace, remove the old label and add the tag label, then check:

```sh
for ns in payments orders; do
  kubectl label namespace "$ns" istio-injection-
  kubectl label namespace "$ns" istio.io/rev=prod --overwrite
done
kubectl get ns payments orders --show-labels
```

```text
NAME       STATUS   AGE   LABELS
payments   Active   10m   istio.io/rev=prod,kubernetes.io/metadata.name=payments
orders     Active   10m   istio.io/rev=prod,kubernetes.io/metadata.name=orders
```

Remove `istio-injection` **first**. With both labels present, `istio-injection` wins and the revision label is ignored. The default webhook's selector requires `istio-injection: enabled`, while the revision webhook requires `istio.io/rev` *and* that `istio-injection` is absent. A namespace with both labels only satisfies the first.

---

## Step 5: Restart everything

Relaunch every Deployment in both namespaces and wait for them:

```sh
kubectl -n payments rollout restart deployment
kubectl -n orders rollout restart deployment
kubectl -n payments rollout status deployment --timeout=300s
kubectl -n orders rollout status deployment --timeout=300s
```

`rollout restart deployment` with no name covers every Deployment in the namespace, `tester` included. That one is easy to forget because it does no visible work.

Check before you go any further, because the next step cannot be undone:

```sh
istioctl-1.30.5 proxy-status
for ns in payments orders; do
  kubectl -n "$ns" get pods \
    -o custom-columns='POD:.metadata.name,REV:.metadata.labels.istio\.io/rev,PROXY:.spec.containers[1].image'
done
```

```text
NAME                              CLUSTER      CDS      LDS      EDS      RDS      ISTIOD
checkout-api-...payments          Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED   istiod-1-30-5-...
checkout-api-...payments          Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED   istiod-1-30-5-...
order-api-...orders               Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED   istiod-1-30-5-...
tester-...orders                  Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED   istiod-1-30-5-...

POD                       REV       PROXY
checkout-api-...          1-30-5    docker.io/istio/proxyv2:1.30.5
```

Every entry in the `ISTIOD` column names the canary pod, and every pod reports `1-30-5`. The pod records the **revision the tag resolved to**, not the tag itself. That proves the tag pointed where you meant.

---

## Step 6: Check for stragglers, then retire

Look for any namespace still labelled for the old control plane:

```sh
kubectl get ns -l istio-injection=enabled
kubectl get ns -l istio.io/rev=default
```

```text
No resources found
No resources found
```

Both are empty. Check these namespace queries as well as `proxy-status`. `proxy-status` catches running pods; the namespace queries catch namespaces whose workloads happen to be scaled to zero right now.

Now retire the default revision by name, and check what is left:

```sh
istioctl uninstall --revision default -y
kubectl -n istio-system get deployments
kubectl get mutatingwebhookconfigurations | grep istio
kubectl get crd | grep -c istio.io
```

```text
NAME            READY   UP-TO-DATE   AVAILABLE   AGE
istiod-1-30-5   1/1     1            1           14m

istio-revision-tag-prod           ...   12m
istio-sidecar-injector-1-30-5     ...   14m

15
```

One control plane is left, with the canary's webhook and the tag's webhook, and the Custom Resource Definitions (CRDs) are intact.

**`--revision default`, never `--purge`.** `--purge` removes every revision, including the one you just promoted, along with the shared cluster-wide resources. That is exactly why the grader checks the CRDs.

---

## Step 7: Submit

Send the mission for grading:

```sh
astrona submit
```

The grader checks that `istiod-1-30-5` runs 1.30.5, that the `istiod` and the `istio-sidecar-injector` webhook without a revision are gone, and that the `networking.istio.io` CRDs survived. It checks that a `prod` tag webhook exists, and that both namespaces carry `istio.io/rev=prod` and not `istio-injection`. Finally it checks that the Deployments kept their names and replica counts, and that all four running pods report revision `1-30-5` on the 1.30.5 proxy.

---

## Common mistakes

*   **Retiring the old revision before restarting.** The most serious error here. Pods keep serving but lose configuration updates and certificate renewal.
*   **`istioctl uninstall --purge`.** Removes the canary and the CRDs with it. Name the revision.
*   **Labelling namespaces with `istio.io/rev=1-30-5` instead of the tag.** It works, but it defeats the purpose: the next upgrade means relabelling every namespace again.
*   **Leaving `istio-injection` on a namespace.** The revision label is ignored, the workload never moves, and the restart injects it again from the old control plane.
*   **Forgetting `tester`.** It does nothing visible, so it is easy to skip, and it is a pod in the mesh that the grader checks.
*   **Installing the revision with the 1.29.8 binary.** You get a revision named `1-30-5` running 1.29.8.
*   **Installing the canary with a full profile.** Two sets of gateways fight over the same names. Use `minimal` for a canary control plane.
