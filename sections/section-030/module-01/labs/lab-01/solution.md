# Solution Walkthrough

Follow these steps to recover the lost configuration, upgrade all three releases without losing it, and finish the job.

---

## Step 1: Recover the Values Before Touching Anything

This is the step that decides whether the rest goes well. Helm stores each release's full state — rendered manifests **and** the values used — in a Secret in the release namespace, and keeps old revisions.

```sh
helm ls -A
helm history istiod -n istio-system
helm get values istiod -n istio-system
```

```text
NAME                    NAMESPACE       REVISION  STATUS    CHART           APP VERSION
istio-base              istio-system    1         deployed  base-1.29.8     1.29.8
istio-ingressgateway    istio-ingress   1         deployed  gateway-1.29.8  1.29.8
istiod                  istio-system    1         deployed  istiod-1.29.8   1.29.8

REVISION  UPDATED       STATUS      CHART          APP VERSION  DESCRIPTION
1         Mon Sep 27..  deployed    istiod-1.29.8  1.29.8       Install complete

USER-SUPPLIED VALUES:
global:
  proxy:
    resources:
      requests:
        cpu: 10m
        memory: 64Mi
meshConfig:
  accessLogFile: /dev/stdout
  outboundTrafficPolicy:
    mode: ALLOW_ANY
pilot:
  autoscaleEnabled: false
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
```

That is the file someone wrote and did not commit, read back out of a Secret. Write it to disk:

```sh
helm get values istiod -n istio-system --revision 1 | tail -n +2 > istiod-values.yaml
cat istiod-values.yaml
```

`tail -n +2` drops the `USER-SUPPLIED VALUES:` header, which is a human-facing line and not part of the YAML.

---

## Step 2: Make the Requested Change in the File

Edit the file rather than adding a `--set`. That keeps the file complete, which is the entire point:

```sh
sed -i.bak 's/mode: ALLOW_ANY/mode: REGISTRY_ONLY/' istiod-values.yaml && rm -f istiod-values.yaml.bak
grep -A2 outboundTrafficPolicy istiod-values.yaml
```

> `-i` takes no argument on GNU sed but requires one on the BSD sed that ships
> with macOS. `-i.bak` works on both: it edits in place and leaves a backup,
> which the `rm` then removes.

```text
  outboundTrafficPolicy:
    mode: REGISTRY_ONLY
```

---

## Step 3: Understand What You Are Avoiding

Worth stating before you run the upgrade, because it is the trap the whole module is about:

```text
  DEFAULT  chart defaults ──► this run's -f ──► this run's --set ──► new release
                 ▲
                 └── the previous revision's values are NOT in this picture
```

`helm upgrade istiod istio/istiod -n istio-system --version 1.30.5` with no `-f` would report `STATUS: deployed` and silently reset access logging, autoscaling and every resource request to chart defaults. `--reuse-values` is the other option, but it merges rather than replaces — a `-f` file that *removes* a key does not remove it. One complete file, passed every time, avoids both.

Check what will happen first:

```sh
helm upgrade istiod istio/istiod -n istio-system --version 1.30.5 \
  -f istiod-values.yaml --dry-run --debug 2>&1 | sed -n '/COMPUTED VALUES/,/HOOKS/p' | head -20
```

If the computed values block is empty or missing keys you expect, stop.

---

## Step 4: Upgrade in Order

`base`, then `istiod`, then the gateway — the same order as the install. At install time the CRDs literally had to exist first; at upgrade time the constraint is schema: a newer `istiod` may set fields only the newer CRDs accept.

```sh
helm upgrade istio-base istio/base -n istio-system --version 1.30.5 --wait
helm upgrade istiod istio/istiod -n istio-system --version 1.30.5 -f istiod-values.yaml --wait
helm upgrade istio-ingressgateway istio/gateway -n istio-ingress --version 1.30.5 --wait
```

```text
Release "istio-base" has been upgraded. Happy Helming!
Release "istiod" has been upgraded. Happy Helming!
Release "istio-ingressgateway" has been upgraded. Happy Helming!
```

Note the `-f` on the middle line only. `base` and `gateway` were installed without a values file, so chart defaults are the correct desired state for them — that is a fact about *this* install, not a general rule. Whatever file a release was installed with is the file it must be upgraded with.

```sh
helm ls -A
kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep -A2 -E 'accessLogFile|outboundTrafficPolicy'
```

```text
NAME                    NAMESPACE       REVISION  STATUS    CHART           APP VERSION
istio-base              istio-system    2         deployed  base-1.30.5     1.30.5
istio-ingressgateway    istio-ingress   2         deployed  gateway-1.30.5  1.30.5
istiod                  istio-system    2         deployed  istiod-1.30.5   1.30.5

accessLogFile: /dev/stdout
outboundTrafficPolicy:
  mode: REGISTRY_ONLY
```

Preserved setting and new setting, side by side. That is the whole exercise in two lines.

---

## Step 5: See the Skew Before You Fix It

```sh
istioctl-1.30.5 version
```

```text
client version: 1.30.5
control plane version: 1.30.5
data plane version: 1.29.8 (2 proxies)
```

A new control plane serving old proxies. This is **version skew**, and it is supported across one minor version — which is exactly what makes a rolling upgrade possible. It is a window to pass through, not a place to stay.

The reason is mechanical: a sidecar's image is fixed at pod creation. Upgrading `istiod` replaces one Deployment; it cannot rewrite the stored spec of every pod in the cluster.

---

## Step 6: Restart the Data Plane

```sh
kubectl -n default rollout restart deployment notification-service
kubectl -n istio-ingress rollout restart deployment istio-ingressgateway
kubectl -n default rollout status deployment notification-service --timeout=180s
kubectl -n istio-ingress rollout status deployment istio-ingressgateway --timeout=180s
```

The gateway is the one people forget. It runs the same Envoy image as a sidecar, installed as its own Deployment, and the control plane upgrade does not restart it — but it is the workload whose staleness is most visible from outside the cluster.

```sh
istioctl-1.30.5 version
```

```text
client version: 1.30.5
control plane version: 1.30.5
data plane version: 1.30.5 (2 proxies)
```

A single `data plane version` matching the control plane is the upgrade being complete.

---

## Step 7: Confirm Everything Survived

```sh
kubectl -n istio-system get hpa
kubectl -n istio-system get deploy istiod -o jsonpath='{.spec.template.spec.containers[0].resources.requests}{"\n"}'
kubectl -n default get pod -l app=notification-service \
  -o jsonpath='{.items[0].spec.containers[?(@.name=="istio-proxy")].resources.requests}{"\n"}'
```

```text
No resources found in istio-system namespace.
{"cpu":"100m","memory":"256Mi"}
{"cpu":"10m","memory":"64Mi"}
```

Three values from an install nobody documented, all intact through a version bump. No HPA proves `autoscaleEnabled: false` survived; the second line proves `pilot.resources` survived; the third proves `global.proxy.resources` survived — and the third one is only observable on a freshly injected pod, which is another reason the restart mattered.

---

## Step 8: Submit

```sh
astrona submit
```

The grader checks every release is `deployed` at revision 2 or higher, that `istiod` and the gateway proxy are both on 1.30.5, that `accessLogFile`, the absent HPA, and both resource blocks survived, that `REGISTRY_ONLY` was applied, and that the application sidecar is on 1.30.5 with the original 10m/64Mi requests.

---

## Common Mistakes

*   **`helm upgrade` with no `-f`.** Everything reverts to chart defaults, the command prints `deployed`, and the exit code is zero. This is the failure the whole lab is built around.
*   **`--reuse-values` with a `-f` that removes a key.** The removal is not honoured — the file merges onto the old values. Pass one complete file instead.
*   **Upgrading `istiod` without `istio-base`.** It often appears to work and then fails later on a field the older CRDs do not accept.
*   **Stopping when Helm says `deployed`.** The data plane is still on 1.29.8. `istioctl version` splitting into two versions is the signal.
*   **Forgetting the gateway.** It needs both the `helm upgrade` *and* the `rollout restart`. The grader checks its image specifically.
*   **Reinstalling with `istioctl` because it is fewer steps.** The Helm release records stop matching the cluster, and the grader reports the release was never upgraded.
*   **Recovering the values file and not committing it.** The cluster being the only copy is the root cause; reconstruction alone just resets the trap.

---

## Reference

The official documentation for everything this task touches — open these rather than trying to recall field names:

- [Install with Helm](https://istio.io/v1.30/docs/setup/install/helm/) — the charts, their values, and install ordering
- [Canary upgrades](https://istio.io/v1.30/docs/setup/upgrade/canary/) — revisions, revision labels and moving workloads between control planes
- [Supported releases and skew](https://istio.io/v1.30/docs/releases/supported-releases/) — how far the data plane may lag the control plane
- [Global mesh options](https://istio.io/v1.30/docs/reference/config/istio.mesh.v1alpha1/) — every mesh-wide setting and its default
- [istioctl command reference](https://istio.io/v1.30/docs/reference/commands/istioctl/) — every subcommand and flag
- [Installing gateways](https://istio.io/v1.30/docs/setup/additional-setup/gateway/) — deploying gateways separately from the control plane
