# Where A Release Lives

Every recovery in this module depends on one fact. Helm keeps its own history inside the cluster, and that history includes the values nobody saved anywhere else. This part shows what Helm stores, where it stores it, and how you read it back.

In space terms, a **Helm release** is one kit from the shipyard, built in your solar system under a name, with a numbered logbook. This part is about that logbook.

## The release record

Helm writes down every build of a release. Here you find where that record is, what is in it, and why it can disappear.

### Find the release records yourself

Start with the real thing. The release records are Secrets with the label `owner=helm`.

<!-- astrona:playground:renew -->

List them, and print the labels of the `istiod` record:

```sh
kubectl -n istio-system get secret -l owner=helm
kubectl -n istio-system get secret -l owner=helm,name=istiod \
  -o jsonpath='{.items[0].metadata.labels}{"\n"}'
```

Expect something like:

```text
NAME                               TYPE                 DATA   AGE
sh.helm.release.v1.istio-base.v1   helm.sh/release.v1   1      9m
sh.helm.release.v1.istiod.v1       helm.sh/release.v1   1      8m

{"name":"istiod","owner":"helm","status":"deployed","version":"1"}
```

The `version` label is the **revision** number, not the chart version. Keep the two apart: `helm history` shows both as columns. `status: deployed` marks the revision that is applied now; earlier revisions carry `superseded`.

### What is inside a release Secret

Helm, not Istio, keeps this record. Each release is a **Secret** in the release's namespace, of type `helm.sh/release.v1`, named `sh.helm.release.v1.<release>.v<revision>`. Inside it is a JSON document, compressed with gzip and then encoded with base64 twice. That document holds:

- the **rendered manifests**: the exact Kubernetes objects this revision applied;
- the **chart metadata**: name, chart version and app version;
- the **supplied values**: what you passed with `-f` and `--set`;
- the **status and timestamps**: `deployed`, `superseded`, `failed`, and when.

Every `install` or `upgrade` writes a *new* Secret and adds one to the revision number, starting at 1. Helm keeps the old revisions. That is what makes `helm history` and `helm rollback` possible at all.

### Two consequences

**The cluster is the source of truth for what Helm did.** Not your disk, and not your pipeline logs. If a colleague installed with a values file on their laptop, the cluster still has a copy of it.

**That history can be deleted.** These are ordinary Secrets. A namespace cleanup that removes them also removes your way back and your way to recover values. There is no warning and no undo.

## The read commands

Four commands answer almost every question about a release. Knowing which one answers which question saves a lot of guessing.

### Which command answers what

| Command | Answers |
| --- | --- |
| `helm ls -A` | What releases exist, at what chart version, on what revision |
| `helm history <rel> -n <ns>` | Every revision of one release, and which one to roll back to |
| `helm get values <rel> -n <ns>` | What values *you supplied* for the current revision |
| `helm get values <rel> -n <ns> --all` | The full set of values in effect, chart defaults included |

`helm get values` also takes `--revision N`. That is the recovery path when an upgrade loses settings.

A fifth command is worth knowing too. `helm get manifest <rel> -n <ns>` prints the rendered Kubernetes objects for a revision. Compare the output for `--revision 1` and `--revision 2`, and you see exactly what an upgrade changed in your cluster.

### See what the cluster knows that your disk does not

Run the first three commands against your playground:

```sh
helm ls -A
helm history istiod -n istio-system
helm get values istiod -n istio-system
```

Expect something like:

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

`USER-SUPPLIED VALUES` is the file someone wrote and never saved, read back out of a Secret. Look at what is at stake in those lines: mesh-wide access logging, mission control's autoscaling and size, and the resource requests of every sidecar (the standard kit of every communications officer).

## Reading `helm history`

`helm history` is the command you use under pressure, so learn to read every column without thinking:

- **`REVISION`**: the number `helm rollback` takes. It only goes up and is never reused.
- **`STATUS`**: `deployed` for the current one, `superseded` for earlier ones, `failed` for an upgrade that hit an error, `pending-upgrade` for one that is still running or was stopped halfway.
- **`CHART`**: the chart name and *chart* version. This is where you see a version change.
- **`APP VERSION`**: the Istio version that chart installs.
- **`DESCRIPTION`**: free text, such as `Install complete`, `Upgrade complete`, `Rollback to 1`, or the error from a failure.

A `failed` revision still takes a number. The history records what happened, not what you meant. So the revision number is not the same as the number of good upgrades.

A `pending-upgrade` status on an upgrade that is no longer running means the upgrade was cut off. Helm refuses the next upgrade until you fix it, normally with `helm rollback` to the last good revision.

## Values in the release or values in a file

The good habit is one complete values file, saved in version control and passed with `-f` on every run. This table shows why:

| | Values in a saved file | Values only in the release |
| --- | --- | --- |
| Can be reviewed before applying | Yes, in a pull request | No |
| Can be compared between versions | Yes, `git diff` | Only with `helm get values --revision` |
| Survives losing the cluster | Yes | No |
| Survives a Secret cleanup | Yes | No |
| Can be recovered after a bad upgrade | Yes, it is right there | Yes, until the history is removed |

The last row is why this mistake can be fixed. The row above it is why you should not count on that.

### Rebuild the file that should have been saved

Pull the values of revision 1 into a file:

```sh
helm get values istiod -n istio-system --revision 1 | tail -n +2 > istiod-values.yaml
head -6 istiod-values.yaml
```

Expect something like:

```text
global:
  proxy:
    resources:
      requests:
        cpu: 10m
        memory: 64Mi
```

`tail -n +2` drops the `USER-SUPPLIED VALUES:` header line, which is for humans and is not part of the YAML. You now hold the file that should have existed all along. In a real recovery, the very next step is to save it in version control. A file rebuilt from a release and left on your laptop just sets the same trap again.

Helm's history is a stack of Secrets in the cluster. It is the only copy of any value nobody saved, and one careless cleanup can remove it.

## Common pitfalls

> [!WARNING]
> **Treating `helm get values` as the source of truth.** It is a recovery tool. The saved values file you pass on every run is the source of truth.
>
> **Deleting `sh.helm.release.v1.*` Secrets to tidy a namespace.** That is the release history. Rollback and value recovery go with it.
>
> **Reading `STATUS: deployed` as a working mesh.** It means the manifests were applied, nothing more.
>
> **Forgetting `--all`.** `helm get values` shows only what you supplied; `--all` shows the full set, chart defaults included.
