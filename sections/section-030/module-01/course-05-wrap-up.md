# Wrap-Up: Mission Debrief

Well flown, astronaut. You have finished every part and the mission in this module. Before you move on, look back at what you learned, check yourself, and land the playground cleanly.

## What you learned

This module was about rebuilding mission control from a newer kit without losing the notes on the old order form: upgrading a Helm-managed Istio and keeping every setting.

**From [Where A Release Lives](./course-01-where-a-release-lives.md):**

- Helm stores each revision of a release as a Secret named `sh.helm.release.v1.<release>.v<revision>`, with the rendered manifests and the supplied values inside.
- `helm ls -A`, `helm history`, `helm get values` and `helm get values --all` answer most questions about a release. `--revision N` reads an older revision.
- The release history can be the only copy of values nobody saved. Deleting those Secrets removes rollback and recovery.

**From [How `helm upgrade` Computes Values](./course-02-how-upgrade-computes-values.md):**

- `helm upgrade` starts from the chart defaults plus only this run's `-f` and `--set`. The previous values are not carried over, and Helm still reports success.
- `--reuse-values` starts from the previous values, but merges a `-f` file onto them, so removed keys stay. `--reset-values` writes out the default behaviour.
- The fix is one complete values file per release, saved in version control and passed with `-f` every time. `--dry-run --debug` shows the computed values before you apply.

**From [Upgrading In Order And Finishing The Job](./course-03-upgrading-in-order-and-finishing.md):**

- Upgrade `base`, then `istiod`, then the gateways, each pinned with `--version`.
- A control plane upgrade leaves every sidecar on its old image: that is version skew. `istioctl version` and `istioctl proxy-status` show it.
- `kubectl rollout restart` finishes the upgrade, for the application namespaces and for the gateway.

**From [Rolling Back And A Safe Procedure](./course-04-rolling-back-and-a-safe-procedure.md):**

- `helm rollback` applies an older revision as a new revision. It restores that release's objects and values only.
- It does not restart pods, does not touch sibling releases, and does not undo anything outside the release.
- A safe upgrade: check the values, dry run, upgrade in order, check the settings, restart the data plane, check for one data plane version.

## Your missions

You proved the skill in a graded mission, right after the part that finished the topic:

| Mission | After the part | What you proved |
| --- | --- | --- |
| [Upgrade And Reconfigure Istio With Helm](./labs/lab-01/README.md) | Rolling Back And A Safe Procedure | recover lost values, upgrade three releases in order with one change, and close the version skew |

If you skipped it, go back to it now.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. You run <code>helm upgrade istiod istio/istiod -n istio-system --version 1.30.5</code> with no other flags. What happens to the values from the install?</summary>

They are dropped. Helm builds the new revision from the chart defaults plus this run's `-f` and `--set`, and there were none. The release shows `deployed`, and `helm get values` shows `null`.
</details>

<details>
<summary>2. Where does Helm keep the values a release was installed with?</summary>

In a Secret of type `helm.sh/release.v1` in the release's namespace, one per revision, named `sh.helm.release.v1.<release>.v<revision>`.
</details>

<details>
<summary>3. How do you get the values of revision 1 back into a file?</summary>

`helm get values istiod -n istio-system --revision 1 | tail -n +2 > istiod-values.yaml`. The `tail -n +2` removes the `USER-SUPPLIED VALUES:` header line.
</details>

<details>
<summary>4. You pass <code>--reuse-values</code> with a <code>-f</code> file that no longer contains a key. Is the key gone after the upgrade?</summary>

No. `--reuse-values` merges the file onto the previous values, so the key is still inherited. To drop it, pass a complete file without `--reuse-values`.
</details>

<details>
<summary>5. In which order do you upgrade the three Istio releases, and why does <code>base</code> go first?</summary>

`base`, `istiod`, then the gateways. A newer `istiod` may use fields that only the newer CRDs from `base` accept.
</details>

<details>
<summary>6. <code>istioctl version</code> shows <code>control plane version: 1.30.5</code> and <code>data plane version: 1.29.8</code>. What is missing?</summary>

A restart of the workloads. Sidecars keep the image they were injected with. `kubectl rollout restart` on every meshed namespace, plus the gateway, finishes the upgrade.
</details>

<details>
<summary>7. You roll <code>istiod</code> back to revision 1. Which version is <code>istio-base</code> on now?</summary>

Still the newer version. `helm rollback` only touches the release you name. `helm ls -A` shows each release's own chart version.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and the mission if it is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-013-playground-030-01
```

If `astrona list` also showed the mission, remove it the same way:

```sh
astrona destroy ats-013-lab-030-01
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.
