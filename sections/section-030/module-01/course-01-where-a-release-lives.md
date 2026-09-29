# Part 1 — Where A Release Lives

> Prerequisite: [the module landing page](./course.md). Next: [Part 2 — How `helm upgrade` Computes Values](./course-02-how-upgrade-computes-values.md).

Every recovery in this module depends on one fact: Helm keeps its own history inside the cluster, and that history includes the values nobody committed. This part establishes what is stored, where, and how to get at it — so that Part 2 can lose configuration on purpose and Part 3 can roll it back.

## The release record

A Helm release's state is a **Secret** in the release's namespace, of type `helm.sh/release.v1`, named `sh.helm.release.v1.<release>.v<revision>`. Inside it, gzipped and base64-encoded twice, is a JSON document containing:

- the **rendered manifests** — the exact Kubernetes objects this revision applied;
- the **chart metadata** — name, chart version, app version;
- the **supplied values** — what you passed with `-f` and `--set`;
- the **status and timestamps** — `deployed`, `superseded`, `failed`, and when.

Every `install` or `upgrade` writes a *new* Secret and increments the revision number, starting at 1. Old revisions are kept, which is what makes `helm history` and `helm rollback` possible at all.

Two consequences worth being explicit about:

**The cluster is the source of truth for what Helm did.** Not your disk, not your CI logs. If a colleague installed with a values file on their laptop, the cluster still has it.

**That history is deletable.** These are ordinary Secrets. A namespace cleanup that removes them removes your rollback path and your ability to recover values, with no warning and no way back.

> [!TIP]
> **Try it — find the release records themselves**
>
> ```sh
> kubectl -n istio-system get secret -l owner=helm
> kubectl -n istio-system get secret -l owner=helm,name=istiod \
>   -o jsonpath='{.items[0].metadata.labels}{"\n"}'
> ```
>
> Expect something like:
>
> ```text
> NAME                               TYPE                 DATA   AGE
> sh.helm.release.v1.istio-base.v1   helm.sh/release.v1   1      9m
> sh.helm.release.v1.istiod.v1       helm.sh/release.v1   1      8m
>
> {"name":"istiod","owner":"helm","status":"deployed","version":"1"}
> ```
>
> The `version` label is the **revision** number, not the chart version — a distinction that matters constantly when reading `helm history`, where both appear as columns. `status: deployed` marks the revision currently applied; earlier ones carry `superseded`.

## The four read commands

Everything you need comes from four commands, and knowing which one answers which question saves a lot of guessing.

| Command | Answers |
| --- | --- |
| `helm ls -A` | What releases exist, at what chart version, on what revision |
| `helm history <rel> -n <ns>` | Every revision of one release, and which to roll back to |
| `helm get values <rel> -n <ns>` | What values *you supplied* for the current revision |
| `helm get values <rel> -n <ns> --all` | The full effective value set, chart defaults included |

`helm get values` also takes `--revision N`, which is the recovery path and the reason Part 2 is survivable.

There is a fifth worth knowing: `helm get manifest <rel> -n <ns>` prints the rendered Kubernetes objects for a revision. Diffing `--revision 1` against `--revision 2` of that output is the most direct answer to "what did this upgrade actually change in my cluster".

> [!TIP]
> **Try it — what the cluster knows that your disk does not**
>
> ```sh
> helm ls -A
> helm history istiod -n istio-system
> helm get values istiod -n istio-system
> ```
>
> Expect something like:
>
> ```text
> NAME                    NAMESPACE       REVISION  STATUS    CHART           APP VERSION
> istio-base              istio-system    1         deployed  base-1.29.8     1.29.8
> istio-ingressgateway    istio-ingress   1         deployed  gateway-1.29.8  1.29.8
> istiod                  istio-system    1         deployed  istiod-1.29.8   1.29.8
>
> REVISION  UPDATED       STATUS      CHART          APP VERSION  DESCRIPTION
> 1         Mon Sep 27..  deployed    istiod-1.29.8  1.29.8       Install complete
>
> USER-SUPPLIED VALUES:
> global:
>   proxy:
>     resources:
>       requests:
>         cpu: 10m
>         memory: 64Mi
> meshConfig:
>   accessLogFile: /dev/stdout
>   outboundTrafficPolicy:
>     mode: ALLOW_ANY
> pilot:
>   autoscaleEnabled: false
>   resources:
>     requests:
>       cpu: 100m
>       memory: 256Mi
> ```
>
> `USER-SUPPLIED VALUES` is the file someone wrote and did not commit, read back out of a Secret. Note what is at stake in those twelve lines: mesh-wide access logging, the control plane's autoscaling and sizing, and every sidecar's resource requests.

## Reading `helm history` properly

`helm history` is the command you will use under pressure, so it is worth being able to read every column without thinking.

- **`REVISION`** — the number `helm rollback` takes. Monotonic, never reused.
- **`STATUS`** — `deployed` for the current one, `superseded` for earlier ones, `failed` for an upgrade that errored, `pending-upgrade` for one still running or abandoned mid-flight.
- **`CHART`** — chart name and *chart* version. This is how you see a version bump.
- **`APP VERSION`** — the Istio version that chart installs.
- **`DESCRIPTION`** — free text: `Install complete`, `Upgrade complete`, `Rollback to 1`, or the error from a failure.

A `failed` revision still occupies a number. That is useful — the history is a record of what happened, not of what you intended — and it means revision numbers and "number of successful upgrades" are not the same count.

A `pending-upgrade` status that is not currently running means an upgrade was interrupted. Helm will refuse the next upgrade until it is resolved, normally with `helm rollback` to the last good revision.

## Values in the release versus values in a file

Both Part 2 and the section 010 Helm module push the same habit — a complete values file, committed, passed with `-f` on every run — and Part 1 is where the reason becomes concrete.

| | Values in a committed file | Values only in the release |
| --- | --- | --- |
| Reviewable before applying | Yes, in a pull request | No |
| Diffable between versions | Yes, `git diff` | Only via `helm get values --revision` |
| Survives cluster loss | Yes | No |
| Survives a Secret cleanup | Yes | No |
| Recoverable after a bad upgrade | Yes, it is right there | Yes, until the history is pruned |

The last row is why this is a recoverable mistake rather than a fatal one, and the row above it is why you should not rely on that.

> [!TIP]
> **Try it — reconstruct the file that should have been committed**
>
> ```sh
> helm get values istiod -n istio-system --revision 1 | tail -n +2 > istiod-values.yaml
> head -6 istiod-values.yaml
> ```
>
> Expect something like:
>
> ```text
> global:
>   proxy:
>     resources:
>       requests:
>         cpu: 10m
>         memory: 64Mi
> ```
>
> `tail -n +2` drops the `USER-SUPPLIED VALUES:` header, which is a human-facing line and not part of the YAML. You now hold the artifact that should have existed all along — and in a real recovery the very next step is a commit, because a file reconstructed from a release and left uncommitted just recreates the same trap.

> *Helm's history is a stack of Secrets in the cluster; it is the only copy of any value nobody committed, and it is one careless cleanup away from being gone.*

## Common pitfalls

> [!WARNING]
> **Treating `helm get values` as the source of truth.** It is a recovery tool; the committed values file you pass on every run is the source of truth.
>
> **Deleting `sh.helm.release.v1.*` Secrets to tidy a namespace.** That is the release history — rollback and value recovery go with it.
>
> **Reading `STATUS: deployed` as a working mesh.** It means the manifests applied, nothing more.
>
> **Forgetting `--all`.** `helm get values` shows only what you supplied; `--all` shows the computed set including chart defaults.

## Reference

- [Helm: release records](https://helm.sh/docs/topics/advanced/#storage-backends) — where release state is kept and how to change the backend.
- [helm get values](https://helm.sh/docs/helm/helm_get_values/) — `--revision` and `--all`.
- [helm history](https://helm.sh/docs/helm/helm_history/) — the status values and what each one means.
- `helm get manifest --help` — the rendered objects for a revision, for diffing upgrades.
