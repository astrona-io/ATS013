# Solution Walkthrough

Follow these steps to check the cluster with the target `istioctl`, upgrade the control plane (`istiod`) in place with the same profile, and restart every workload, the ingress gateway included, so no sidecar proxy is left on the old version.

---

## Step 1: Record the starting point

Note the versions, the `istiod` Deployment's `uid`, and the proxy status:

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

The `uid` is the unique ID Kubernetes gives an object when it creates it. Write it down. After the upgrade the image will be different and the `uid` will **not**. That turns "in place" into something you can check. There are four proxies: two replicas, the `tester`, and the gateway.

---

## Step 2: Pre-check with the target binary

Run the pre-upgrade check with the 1.30.5 binary:

```sh
istioctl-1.30.5 x precheck
```

```text
✔ No issues found when checking the cluster. Istio is safe to install or upgrade!
```

Use the **new** binary. The check asks whether this cluster can accept that version. It compares the Kubernetes version with the target's supported range, and looks for leftover Custom Resource Definitions (CRDs), old webhooks, and configuration that uses fields the target has removed. Only the target's binary knows what the target needs.

On a clean cluster this passes easily. On a real cluster the warnings are the whole value: they name what will break *after* the upgrade, while the old version still runs and you still have options.

---

## Step 3: Upgrade in place

Install 1.30.5 with the same profile the cluster was installed with:

```sh
istioctl-1.30.5 install --set profile=default -y
```

```text
✔ Istio core installed
✔ Istiod installed
✔ Ingress gateways installed
✔ Installation complete
```

`istioctl upgrade` also exists and is an alias for `install`, with the same flags and behaviour, so either command works here.

**Pass the same configuration you installed with.** `istioctl install` makes the cluster match the configuration you give it. So a bare `istioctl install -y` means "make the cluster match the *default* profile", and it reverts any custom settings. This cluster was installed with `--set profile=default`, so that is what the upgrade repeats. On a cluster installed from a file, you would pass the same `-f`.

Check the image, the `uid` and the Deployments:

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

A new image, the **same `uid`**, and one `istiod`. Nobody deleted and recreated the Deployment: `istioctl` updated it, and Kubernetes rolled its pods. A canary upgrade would instead have added a second Deployment with a different name.

---

## Step 4: Look at the skew before you fix it

Read the versions and proxy status, and send one request from the `tester` pod to the `notification-service` Service:

```sh
istioctl-1.30.5 version
istioctl-1.30.5 proxy-status
kubectl -n inplace-demo exec deploy/tester -c tester -- \
  curl -s -o /dev/null -w '%{http_code}\n' http://notification-service/
```

The output looks like this (shortened):

```text
client version: 1.30.5
control plane version: 1.30.5
data plane version: 1.29.8 (4 proxies)

NAME                                     CLUSTER      CDS      LDS      EDS      RDS        ISTIOD
notification-service-v1-...inplace-demo  Kubernetes   SYNCED   SYNCED   SYNCED   SYNCED     istiod-5f4c9d8b7c-w8t4n
...

200
```

Control plane 1.30.5, data plane 1.29.8, every proxy `SYNCED`, and traffic returning `200`. This is **version skew**: a new control plane sending configuration to proxies that still run the old version. Istio supports it across one minor version, which is what makes a rolling upgrade possible. Nothing is broken; the upgrade is just not finished.

That limit is also why you never skip a minor version. Going from 1.28 to 1.30 would put every running proxy two minor versions behind the control plane for the whole upgrade, outside the supported window.

---

## Step 5: Restart everything

Restart every Deployment in `inplace-demo` and the gateway, and wait for them:

```sh
kubectl -n inplace-demo rollout restart deployment
kubectl -n istio-system rollout restart deployment istio-ingressgateway
kubectl -n inplace-demo rollout status deployment --timeout=180s
kubectl -n istio-system rollout status deployment istio-ingressgateway --timeout=180s
```

`kubectl -n inplace-demo rollout restart deployment` with no name restarts every Deployment in the namespace: both `notification-service-v1` and `tester`. The gateway needs its own command, because it lives in `istio-system` and no namespace label drives it.

With two replicas you can watch the change instead of guessing it. Run `proxy-status` while the rollout is running and you see entries on both versions at once.

Read the versions again:

```sh
istioctl-1.30.5 version
```

```text
client version: 1.30.5
control plane version: 1.30.5
data plane version: 1.30.5 (4 proxies)
```

A single `data plane version` that matches the control plane means the upgrade is complete.

---

## Step 6: Submit

Send the lab for grading:

```sh
astrona submit
```

The grader checks that there is exactly **one** `istiod` Deployment and no revision webhook, which proves this was in place and not a canary. It checks that `istiod` and the ingress gateway both run 1.30.5, and that `inplace-demo` still holds two Deployments, with two ready replicas of `notification-service-v1`. Finally it checks that **every** running pod in the namespace has an `istio-proxy` on 1.30.5.

---

## Common mistakes

*   **Adding `--set revision=...` out of habit.** That installs a second control plane next to the first. The grader counts `istiod` Deployments and names the ones it found.
*   **Running a bare `istioctl install -y`.** It makes the cluster match the default profile. On this cluster that happens to be right; on any customised cluster it quietly throws configuration away. Always pass the configuration you installed with.
*   **Pre-checking with the old binary.** `istioctl x precheck` must be run with the target version, or it checks compatibility with the version you already have.
*   **Stopping when the control plane is new.** The mesh keeps working in skew, so nothing complains. `istioctl version` showing two versions is the sign.
*   **Restarting the application namespace but not the gateway.** It is a proxy too, it lives in `istio-system`, and the grader checks its image.
*   **Forgetting `tester`.** `rollout restart deployment` with no name covers it. Naming only `notification-service-v1` leaves an old proxy that the grader will find.
*   **Skipping a minor version.** You cannot do it in this lab, but the reason matters: the supported skew window is one minor version, and it applies to each workload.
