# Wrap-Up: Mission Debrief

Well flown, astronaut. You have finished every part and the mission in this module. Before you move on, look back at what you learned, check yourself, and land the playground cleanly.

## What you learned

This module was about replacing mission control in the same building: an in-place upgrade, and the restarts that finish it.

**From [Replacing The Control Plane](./course-01-replacing-the-control-plane.md):**

- An in-place upgrade reuses the same revision. The `istiod` Deployment keeps its name and `uid`, and only its image changes.
- Run `istioctl x precheck` with the **target** binary, before the upgrade. Run `istioctl analyze` after it.
- Upgrade with the same configuration you installed with, for example `istioctl-1.30.5 install --set profile=default -y`. A bare `istioctl install -y` resets the cluster to the default profile.
- While `istiod` rolls, existing proxies keep working, but new pods in namespaces with injection cannot start. Two `istiod` replicas remove that gap.

**From [Skew, Completion And The Cost Of Reverting](./course-02-skew-completion-and-reverting.md):**

- After the upgrade, every proxy still runs its old image: version skew. Istio supports one minor version of it, so never skip a minor version.
- `kubectl rollout restart` ends the skew, one pod at a time. The ingress gateway needs its own restart.
- Going back from an in-place upgrade means reinstalling the old version and restarting the whole data plane again. A canary makes going back a label or tag change.

## Your missions

You proved the skill in a graded mission, right after the part that finished the topic:

| Mission | After the part | What you proved |
| --- | --- | --- |
| [In-Place Upgrade](./labs/lab-01/README.md) | Skew, Completion And The Cost Of Reverting | pre-check with the target binary, replace the control plane in place, and restart every proxy onto 1.30.5 |

If you skipped it, go back to it now.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. After an in-place upgrade, how can you prove the <code>istiod</code> Deployment was updated and not replaced?</summary>

Compare its `metadata.uid` before and after. The image changes, the `uid` stays the same.
</details>

<details>
<summary>2. Why do you run <code>istioctl x precheck</code> with <code>istioctl-1.30.5</code> and not with the installed <code>istioctl</code>?</summary>

The check asks whether the cluster can accept the target version. Only the target's binary knows that version's requirements and deprecations.
</details>

<details>
<summary>3. The cluster was installed with <code>--set profile=default</code>. You upgrade with a bare <code>istioctl-1.30.5 install -y</code>. Is that safe in general?</summary>

Only by luck here. `istioctl install` makes the cluster match the configuration you pass, so on a customised cluster a bare install throws the custom settings away. Always pass the same `-f` file or `--set` flags you installed with.
</details>

<details>
<summary>4. <code>istioctl version</code> shows <code>control plane version: 1.30.5</code> and <code>data plane version: 1.29.8</code>, and traffic returns <code>200</code>. Is the upgrade done?</summary>

No. That is version skew. It is supported, but the upgrade is only finished when every workload, the gateway included, has been restarted and one data plane version is listed.
</details>

<details>
<summary>5. Why can you not upgrade from 1.28 straight to 1.30?</summary>

Istio supports a skew of one minor version. A direct jump would leave every running proxy two minor versions behind the control plane for the whole upgrade.
</details>

<details>
<summary>6. What happens to new pods in a namespace with injection while the only <code>istiod</code> pod restarts?</summary>

They fail to start. The injection webhook's `failurePolicy` is `Fail`, so admission rejects them instead of creating pods without a sidecar.
</details>

<details>
<summary>7. What does going back cost after an in-place upgrade, compared with a canary?</summary>

In place: reinstall the old version with the old configuration, then restart the whole data plane again. Canary: move the label or tag back, then restart at your own pace, because the old control plane is still running.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and the mission if it is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-013-playground-030-03
```

If `astrona list` also showed the mission, remove it the same way:

```sh
astrona destroy ats-013-lab-030-03
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.
