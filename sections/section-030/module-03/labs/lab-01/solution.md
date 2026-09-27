# Solution Walkthrough

Follow these steps to replace the control plane in place and then close the skew window it opens.

---

## Step 1: Record the Baseline

```sh
istioctl version
kubectl -n istio-system get deploy istiod -o jsonpath='{.metadata.uid}{"\n"}'
istioctl proxy-status
```

```text
client version: 1.29.8
control plane version: 1.29.8
data plane version: 1.29.8 (4 proxies)

4b1e9c2a-3d77-4f21-9c8e-2a1f6d4b8e03

NAME                                     CLUSTER      CDS      LDS      EDS      RDS        ISTIOD
istio-ingressgateway-...istio-system     Kubernetes   SYNCED   SYNCED   SYNCED   NOT SENT   istiod-...
notification-service-v1-...inplace-demo  Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED     istiod-...
notification-service-v1-...inplace-demo  Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED     istiod-...
tester-...inplace-demo                   Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED     istiod-...
```

Write the `uid` down. After the upgrade the image will have changed and the `uid` will **not** — that is "in place" made checkable rather than taken on trust. Four proxies: two replicas, the tester, and the gateway.

---

## Step 2: Pre-check With the Target Binary

```sh
istioctl-1.30.5 x precheck
```

```text
✔ No issues found when checking the cluster. Istio is safe to install or upgrade!
```

Run it with the **new** binary. The check asks whether this cluster can accept that version — it inspects the Kubernetes version against the target's supported range, leftover CRDs, stale webhooks, and configuration using fields the target has removed. Only the target's binary knows what the target requires.

On a clean playground this passes trivially. On a real cluster the warnings are the whole value: they name what will break *after* the upgrade, while the old version is still running and you still have options.

---

## Step 3: Upgrade in Place

```sh
istioctl-1.30.5 install --set profile=default -y
```

```text
✔ Istio core installed
✔ Istiod installed
✔ Ingress gateways installed
✔ Installation complete
```

`istioctl upgrade` also exists and is an alias for `install` — identical flags and behaviour, so either command works here.

**Pass the same configuration you installed with.** `istioctl install` reconciles the cluster to the document you give it, so a bare `istioctl install -y` means "make the cluster match the *default* profile", reverting any customisation. This cluster was installed with `--set profile=default`, so that is what the upgrade repeats. On a cluster installed from a file, you would pass the same `-f`.

```sh
kubectl -n istio-system get deploy istiod -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n istio-system get deploy istiod -o jsonpath='{.metadata.uid}{"\n"}'
kubectl -n istio-system get deployments
```

```text
docker.io/istio/pilot:1.30.5
4b1e9c2a-3d77-4f21-9c8e-2a1f6d4b8e03
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
istio-ingressgateway   1/1     1            1           14m
istiod                 1/1     1            1           14m
```

New image, **same uid**, one `istiod`. The Deployment was never deleted and recreated — Istio updated it and Kubernetes rolled its pods. Contrast with the canary module, where a second Deployment under a different name appeared.

---

## Step 4: Look at the Skew Before Fixing It

```sh
istioctl-1.30.5 version
istioctl-1.30.5 proxy-status
kubectl -n inplace-demo exec deploy/tester -c tester -- \
  curl -s -o /dev/null -w '%{http_code}\n' http://notification-service/
```

```text
client version: 1.30.5
control plane version: 1.30.5
data plane version: 1.29.8 (4 proxies)

NAME                                     CLUSTER      CDS      LDS      EDS      RDS        ISTIOD
notification-service-v1-...inplace-demo  Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED     istiod-5f4c9d8b7c-w8t4n
...

200
```

Control plane 1.30.5, data plane 1.29.8, every proxy `SYNCED`, traffic returning `200`. This is **version skew** — supported across one minor version, which is precisely what makes a rolling upgrade possible. Nothing is broken; the upgrade is not finished.

That support is also why you never skip a minor version: 1.28 → 1.30 would put every running proxy two minors behind the control plane for the whole upgrade, outside the supported window.

---

## Step 5: Restart Everything

```sh
kubectl -n inplace-demo rollout restart deployment
kubectl -n istio-system rollout restart deployment istio-ingressgateway
kubectl -n inplace-demo rollout status deployment --timeout=180s
kubectl -n istio-system rollout status deployment istio-ingressgateway --timeout=180s
```

`kubectl -n inplace-demo rollout restart deployment` with no name restarts every Deployment in the namespace — both `notification-service-v1` and `tester`. The gateway needs a separate command because it lives in `istio-system` and no namespace label drives it.

With two replicas you can watch the transition rather than infer it. Run `proxy-status` while the rollout is in flight and you will see entries on both versions at once.

```sh
istioctl-1.30.5 version
```

```text
client version: 1.30.5
control plane version: 1.30.5
data plane version: 1.30.5 (4 proxies)
```

A single `data plane version` matching the control plane is the upgrade being complete.

---

## Step 6: Submit

```sh
astrona submit
```

The grader checks that there is exactly **one** `istiod` Deployment and no revisioned webhook — proving this was in-place and not a canary — that `istiod` and the ingress gateway are both on 1.30.5, that `inplace-demo` still holds two Deployments with two ready replicas, and that **every** running pod in the namespace has an `istio-proxy` on 1.30.5.

---

## Common Mistakes

*   **Adding `--set revision=...` out of habit.** That installs a second control plane beside the first. The grader counts `istiod` Deployments and names the ones it found.
*   **Running a bare `istioctl install -y`.** It reconciles to the default profile. On this cluster that happens to be correct; on any customised cluster it silently discards configuration. Always pass the configuration you installed with.
*   **Pre-checking with the old binary.** `istioctl x precheck` must be run with the target version, or it checks compatibility with the version you already have.
*   **Stopping when the control plane is new.** The mesh keeps working in skew, so nothing complains. `istioctl version` splitting into two versions is the signal.
*   **Restarting the application namespace but not the gateway.** It is a proxy too, it lives in `istio-system`, and the grader checks its image specifically.
*   **Forgetting `tester`.** `rollout restart deployment` with no name covers it; naming only `notification-service-v1` leaves a stale proxy the grader will find.
*   **Skipping a minor version.** Not possible in this lab, but the reason matters: the supported skew window is one minor version, and it applies per workload.
