# Solution Walkthrough

Mission debrief, astronaut. The settings were never lost: Helm kept them in its release history. The work is to get them back into a file, pass that file on the upgrade, and then relaunch the ships so their communications officers run the new version too.

---

## Step 1: Recover the values before you touch anything

This step decides whether the rest goes well. Helm stores each release's full state, the rendered manifests **and** the values used, in a Secret in the release's namespace. It also keeps the old revisions. Read the releases, the history of `istiod`, and its values:

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

That is the file someone wrote and never saved, read back out of a Secret. Write it to disk:

```sh
helm get values istiod -n istio-system --revision 1 | tail -n +2 > istiod-values.yaml
cat istiod-values.yaml
```

`tail -n +2` drops the `USER-SUPPLIED VALUES:` header line, which is for humans and is not part of the YAML.

---

## Step 2: Make the requested change in the file

Edit the file instead of adding a `--set`. That keeps the file complete, which is the whole point:

```sh
sed -i.bak 's/mode: ALLOW_ANY/mode: REGISTRY_ONLY/' istiod-values.yaml && rm -f istiod-values.yaml.bak
grep -A2 outboundTrafficPolicy istiod-values.yaml
```

`-i` takes no argument on GNU sed but needs one on the BSD sed that ships with macOS. `-i.bak` works on both: it edits in place and leaves a backup, which the `rm` then removes.

```text
  outboundTrafficPolicy:
    mode: REGISTRY_ONLY
```

---

## Step 3: Know the trap you are avoiding

This is the trap the whole mission is built around. A default `helm upgrade` starts from the chart's defaults:

```text
  DEFAULT  chart defaults ──► this run's -f ──► this run's --set ──► new release
                 ▲
                 └── the previous revision's values are NOT in this picture
```

`helm upgrade istiod istio/istiod -n istio-system --version 1.30.5` with no `-f` would report `STATUS: deployed` and quietly reset access logging, autoscaling and every resource request to the chart defaults. `--reuse-values` is the other option, but it merges instead of replacing: a `-f` file that *removes* a key does not remove it. One complete file, passed every time, avoids both.

Check what will happen first, with a dry run that changes nothing:

```sh
helm upgrade istiod istio/istiod -n istio-system --version 1.30.5 \
  -f istiod-values.yaml --dry-run --debug 2>&1 | sed -n '/COMPUTED VALUES/,/HOOKS/p' | head -20
```

If the computed values block is empty or misses keys you expect, stop.

---

## Step 4: Upgrade in order

Upgrade `base`, then `istiod`, then the gateway: the same order as the install. `base` holds the Custom Resource Definitions (CRDs), the forms that teach the cluster Istio's object kinds. A newer `istiod` may set fields that only the newer CRDs accept, so `base` goes first.

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

Only the middle line has `-f`. `base` and `gateway` were installed without a values file, so the chart defaults are the right desired state for them. That is a fact about *this* install, not a general rule: whatever file a release was installed with is the file you upgrade it with.

Now check the releases and the mesh settings:

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

The kept setting and the new setting, side by side. That is the whole exercise in two lines.

---

## Step 5: See the skew before you fix it

Use the new `istioctl` binary to compare the versions:

```sh
istioctl-1.30.5 version
```

```text
client version: 1.30.5
control plane version: 1.30.5
data plane version: 1.29.8 (2 proxies)
```

A new mission control is giving orders to communications officers on old software. This is **version skew**. Istio supports it across one minor version, which is what makes a rolling upgrade possible. It is a window to pass through, not a place to stay.

The reason is simple: the injection webhook fixes a sidecar's image when the pod is created. Upgrading `istiod` replaces one Deployment. It cannot rewrite the stored spec of every pod in the cluster.

---

## Step 6: Restart the data plane

Relaunch the application and the gateway so each gets a new proxy, and wait for both:

```sh
kubectl -n default rollout restart deployment notification-service
kubectl -n istio-ingress rollout restart deployment istio-ingressgateway
kubectl -n default rollout status deployment notification-service --timeout=180s
kubectl -n istio-ingress rollout status deployment istio-ingressgateway --timeout=180s
```

The gateway is the one people forget. It runs the same Envoy image as a sidecar, as its own Deployment, and the control plane upgrade does not restart it. Yet it is the workload whose old version is most visible from outside the cluster.

Compare the versions again:

```sh
istioctl-1.30.5 version
```

```text
client version: 1.30.5
control plane version: 1.30.5
data plane version: 1.30.5 (2 proxies)
```

A single `data plane version` that matches the control plane means the upgrade is complete.

---

## Step 7: Confirm everything survived

Read the autoscaler, the resource requests of `istiod`, and the resource requests of the new sidecar:

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

Three settings from an install nobody wrote down, all intact after a version change. No HorizontalPodAutoscaler proves `autoscaleEnabled: false` survived. The second line proves `pilot.resources` survived. The third proves `global.proxy.resources` survived, and you can only see that on a newly injected pod: one more reason the restart mattered.

---

## Step 8: Submit

Send the mission for grading:

```sh
astrona submit
```

The grader checks that every release is `deployed` at revision 2 or higher, and that `istiod` and the gateway proxy both run 1.30.5. It checks that `accessLogFile`, the missing HorizontalPodAutoscaler and both resource blocks survived, and that `REGISTRY_ONLY` was applied. Finally it checks that the application sidecar runs 1.30.5 with the original `10m` and `64Mi` requests.

---

## Common mistakes

*   **`helm upgrade` with no `-f`.** Everything goes back to chart defaults, the command prints `deployed`, and the exit code is zero. This is the failure the whole lab is built around.
*   **`--reuse-values` with a `-f` that removes a key.** Helm ignores the removal and merges the file onto the old values. Pass one complete file instead.
*   **Upgrading `istiod` without `istio-base`.** It often seems to work, then fails later on a field the older CRDs do not accept.
*   **Stopping when Helm says `deployed`.** The data plane is still on 1.29.8. `istioctl version` splitting into two versions is the signal.
*   **Forgetting the gateway.** It needs both the `helm upgrade` *and* the `rollout restart`. The grader checks its image.
*   **Reinstalling with `istioctl` because it is fewer steps.** The Helm release records stop matching the cluster, and the grader reports that the release was never upgraded.
*   **Recovering the values file and not saving it.** The cluster being the only copy is the real cause. Rebuilding the file alone just sets the trap again.
