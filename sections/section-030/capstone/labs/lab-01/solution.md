# Solution Walkthrough

Read this only after you have attempted the specification.

---

## Step 1: The Order Is the Exercise

Five operations, and one ordering constraint that carries the whole point:

```text
  1. install revision 1-30-5          (non-disruptive)
  2. create tag prod -> 1-30-5        (non-disruptive)
  3. relabel both namespaces          (non-disruptive)
  4. restart every workload           ← THIS is the upgrade
  5. retire the default revision      ← only after 4
```

Steps 1–3 change nothing for running pods. Step 4 is where workloads actually move. Step 5 before step 4 leaves pods attached to a control plane that no longer exists: they keep serving on their last-received configuration, but receive no updates and cannot renew their workload certificate when it expires. The failure arrives hours later and looks unrelated.

---

## Step 2: Install the Canary Revision

```sh
istioctl-1.30.5 install --set profile=minimal --set revision=1-30-5 -y
kubectl -n istio-system get pods -l app=istiod
```

```text
NAME                             READY   STATUS    RESTARTS   AGE
istiod-1-30-5-6b9c8f7d4b-xk2p9   1/1     Running   0          42s
istiod-77d5f6c8b9-qr4tz          1/1     Running   0          8m
```

The revision suffixes every namespaced object the install owns, and Istio's reconciliation is scoped by the `istio.io/rev` ownership label — so this install cannot see or prune the default revision's objects. That scoping is what lets two control planes coexist.

Use the **1.30.5 binary**. `istioctl install --set revision=1-30-5` run with the 1.29.8 binary creates a revision *named* `1-30-5` running **1.29.8**; the name is just a string, the version comes from the binary.

---

## Step 3: Create the Tag

```sh
istioctl-1.30.5 tag set prod --revision 1-30-5 -y
istioctl-1.30.5 tag list
```

```text
TAG      REVISION   NAMESPACES
default  default
prod     1-30-5
```

The tag is another mutating webhook configuration whose selector matches `istio.io/rev=prod` and whose backend is the tagged revision's Service. With two namespaces the saving looks small; with fifty it is the difference between one command and fifty chances to miss one.

---

## Step 4: Move Both Namespaces

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

Remove `istio-injection` **first**. With both labels present, `istio-injection` wins and the revision label is ignored — the default webhook's selector requires `istio-injection: enabled`, while the revisioned one requires `istio.io/rev` *and* that `istio-injection` is absent. A namespace with both satisfies only the first.

---

## Step 5: Restart Everything

```sh
kubectl -n payments rollout restart deployment
kubectl -n orders rollout restart deployment
kubectl -n payments rollout status deployment --timeout=300s
kubectl -n orders rollout status deployment --timeout=300s
```

`rollout restart deployment` with no name covers every Deployment in the namespace — `tester` included, which is easy to forget because it does no work.

Verify before going any further, because the next step is the irreversible one:

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

Every entry in the `ISTIOD` column naming the canary pod, and every pod reporting `istio.io/rev=1-30-5`. Note the pod label is the **resolved revision**, not the tag — which is the proof the tag pointed where you meant.

---

## Step 6: Check for Stragglers, Then Retire

```sh
kubectl get ns -l istio-injection=enabled
kubectl get ns -l istio.io/rev=default
```

```text
No resources found
No resources found
```

Both empty. Check the namespace queries as well as `proxy-status`: the first catches running pods, the second catches namespaces whose workloads happen to be scaled to zero right now.

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

One control plane left, the canary's webhook and the tag's webhook, and the CRDs intact.

**`--revision default`, never `--purge`.** `--purge` removes every revision — including the one you just promoted — along with the shared cluster-scoped resources. The grader checks the CRDs specifically for exactly this reason.

---

## Step 7: Submit

```sh
astrona submit
```

The grader checks that `istiod-1-30-5` is the only control plane, that the unrevisioned `istiod` and its webhook are gone, that the `networking.istio.io` CRDs survived, that a `prod` tag webhook exists, that both namespaces carry `istio.io/rev=prod` and not `istio-injection`, that the Deployments kept their shapes, and that all four running pods report revision `1-30-5` on the 1.30.5 proxy.

---

## Common Mistakes

*   **Retiring the old revision before restarting.** The most serious error here. Pods keep serving but lose configuration updates and certificate renewal.
*   **`istioctl uninstall --purge`.** Removes the canary and the CRDs with it. Name the revision.
*   **Labelling namespaces with `istio.io/rev=1-30-5` instead of the tag.** It works and defeats the purpose — the next upgrade is back to relabelling every namespace.
*   **Leaving `istio-injection` on a namespace.** The revision label is ignored, the workload never moves, and the restart re-injects it from the old control plane.
*   **Forgetting `tester`.** It does nothing visible, so it is easy to skip — and it is a meshed pod the grader checks.
*   **Installing the revision with the 1.29.8 binary.** You get a revision named `1-30-5` running 1.29.8.
*   **Installing the canary with a full profile.** Two sets of gateways contend for the same names. `minimal` is a canary control plane.
