# Where A Release Lives

Before you upgrade anything, you need to know what the cluster runs now and how it was configured. With Helm, that answer is not on your disk. A **Helm release** is one installed copy of a chart, under a name you choose, with a numbered history of every install and upgrade. Helm keeps that history inside the cluster, and the history includes values that nobody saved anywhere else. This part shows what Helm stores, where it stores it, and how you read it back.

## The release record

Helm writes down every install and every upgrade of a release. The record is a set of Kubernetes Secrets in the release's namespace, and each one carries the label `owner=helm`. Start by looking at them directly.

<!-- astrona:playground:renew -->

List the release Secrets in `istio-system`, and print the labels of the `istiod` record:

```sh
kubectl -n istio-system get secret -l owner=helm
kubectl -n istio-system get secret -l owner=helm,name=istiod \
  -o jsonpath='{.items[0].metadata.labels}{"\n"}'
```

The output looks like this:

```text
NAME                               TYPE                 DATA   AGE
sh.helm.release.v1.istio-base.v1   helm.sh/release.v1   1      9m
sh.helm.release.v1.istiod.v1       helm.sh/release.v1   1      8m

{"name":"istiod","owner":"helm","status":"deployed","version":"1"}
```

The `version` label is the **revision** number, not the chart version. A revision is one numbered entry in the release history. Keep the two numbers apart: `helm history` shows both as separate columns. `status: deployed` marks the revision that is applied now, and earlier revisions carry `superseded`.

## What is inside a release Secret

Those labels are only the outside of the record. Helm, not Istio, writes each release Secret. Its type is `helm.sh/release.v1`, and its name is `sh.helm.release.v1.<release>.v<revision>`. Inside it is a JSON document, compressed with gzip and then encoded with base64 twice. That document holds:

- the **rendered manifests**: the exact Kubernetes objects this revision applied;
- the **chart metadata**: name, chart version and app version;
- the **supplied values**: what you passed with `-f` and `--set`;
- the **status and timestamps**: `deployed`, `superseded`, `failed`, and when.

Every `install` or `upgrade` writes a *new* Secret and adds one to the revision number, starting at 1. Helm keeps the old revisions. That is what makes `helm history` and `helm rollback` possible.

Two results follow from this. First, the cluster is the source of truth for what Helm did, not your disk and not your pipeline logs. If a colleague installed with a values file on their laptop, the cluster still has a copy of it. Second, that history can be deleted. These are ordinary Secrets, so a namespace cleanup that removes them also removes your way back and your way to recover values. Kubernetes gives no warning and has no undo.

## The read commands

You rarely need to decode a release Secret by hand, because Helm has commands that read it for you. Four commands answer almost every question about a release:

| Command | Answers |
| --- | --- |
| `helm ls -A` | What releases exist, at what chart version, on what revision |
| `helm history <rel> -n <ns>` | Every revision of one release, and which one to roll back to |
| `helm get values <rel> -n <ns>` | What values *you supplied* for the current revision |
| `helm get values <rel> -n <ns> --all` | The full set of values in effect, chart defaults included |

`helm get values` also takes `--revision N`, which reads the values of an older revision. That is the recovery path when an upgrade loses settings. A fifth command, `helm get manifest <rel> -n <ns>`, prints the rendered Kubernetes objects for a revision. If you compare its output for `--revision 1` and `--revision 2`, you see exactly what an upgrade changed in your cluster.

Run the first three commands against your playground:

```sh
helm ls -A
helm history istiod -n istio-system
helm get values istiod -n istio-system
```

The output looks like this (shortened):

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

`USER-SUPPLIED VALUES` is the file someone wrote and never saved, read back out of a Secret. Look at what depends on those lines. `meshConfig.accessLogFile` turns on access logging for every proxy in the mesh. The `pilot` block sets the size of `istiod` and switches off its autoscaling. The `global.proxy.resources` block sets the resource requests of every sidecar proxy that `istiod` injects.

## Reading `helm history`

Of these commands, `helm history` is the one you use under pressure, when an upgrade went wrong and you must pick a revision to go back to. Learn to read every column:

- **`REVISION`**: the number `helm rollback` takes. It only goes up and is never reused.
- **`STATUS`**: `deployed` for the current one, `superseded` for earlier ones, `failed` for an upgrade that hit an error, `pending-upgrade` for one that is still running or was stopped halfway.
- **`CHART`**: the chart name and *chart* version. This is where you see a version change.
- **`APP VERSION`**: the Istio version that chart installs.
- **`DESCRIPTION`**: free text, such as `Install complete`, `Upgrade complete`, `Rollback to 1`, or the error from a failure.

A `failed` revision still takes a number, because the history records what happened, not what you meant. So the revision number is not the same as the number of good upgrades. A `pending-upgrade` status on an upgrade that is no longer running means the upgrade was cut off. Helm refuses the next upgrade until you fix it, normally with `helm rollback` to the last good revision.

## Values in the release or values in a file

Reading the history shows that recovery is possible. It does not make the release history a good place to keep your settings. The good habit is one complete values file, saved in version control and passed with `-f` on every run. This table shows why:

| | Values in a saved file | Values only in the release |
| --- | --- | --- |
| Can be reviewed before applying | Yes, in a pull request | No |
| Can be compared between versions | Yes, `git diff` | Only with `helm get values --revision` |
| Survives losing the cluster | Yes | No |
| Survives a Secret cleanup | Yes | No |
| Can be recovered after a bad upgrade | Yes, it is right there | Yes, until the history is removed |

The last row is why this mistake can be fixed. The row above it is why you should not count on that.

Pull the values of revision 1 into a file, and look at the first lines:

```sh
helm get values istiod -n istio-system --revision 1 | tail -n +2 > istiod-values.yaml
head -6 istiod-values.yaml
```

The output looks like this:

```text
global:
  proxy:
    resources:
      requests:
        cpu: 10m
        memory: 64Mi
```

`tail -n +2` drops the `USER-SUPPLIED VALUES:` header line, which is for people to read and is not part of the YAML. You now hold the file that should have existed all along. In a real recovery, the next step is to save it in version control. A file rebuilt from a release and left on your laptop sets the same trap again.

You now know that Helm keeps one Secret per revision in the release's namespace, with the rendered objects and the supplied values inside, and that `helm ls`, `helm history` and `helm get values` read it back. That history can be the only copy of a setting nobody saved. The open question is what `helm upgrade` does with those stored values when you run it.

## Common pitfalls

> [!WARNING]
> **Treating `helm get values` as the source of truth.** It is a recovery tool. The saved values file you pass on every run is the source of truth.
>
> **Deleting `sh.helm.release.v1.*` Secrets to tidy a namespace.** That is the release history. Rollback and value recovery go with it.
>
> **Reading `STATUS: deployed` as a working mesh.** It means Helm applied the manifests, nothing more.
>
> **Forgetting `--all`.** `helm get values` shows only what you supplied; `--all` shows the full set, chart defaults included.
