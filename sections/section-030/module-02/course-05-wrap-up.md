# Wrap-Up: Mission Debrief

Well flown, astronaut. You have finished every part and the mission in this module. Before you move on, look back at what you learned, check yourself, and land the playground cleanly.

## What you learned

This module was about building a second mission control next to the first and moving planets over one at a time: a canary upgrade.

**From [Revisions: A Named Control Plane](./course-01-revisions-a-named-control-plane.md):**

- `--set revision=1-30-5` creates `istiod-1-30-5`, its own Service and its own webhook `istio-sidecar-injector-1-30-5`, next to the default ones.
- Revision names must be valid DNS labels, so `1-30-5`, never `1.30.5`. The CRDs are shared by every revision.
- Installing a revision moves nothing. The `ISTIOD` column of `istioctl proxy-status` shows which control plane pod serves each proxy.

**From [Moving A Namespace To A Revision](./course-02-moving-a-namespace-to-a-revision.md):**

- `istio-injection=enabled` selects the default control plane; `istio.io/rev=<name>` selects a revision. With both present, `istio-injection` wins quietly.
- A move is three steps: remove `istio-injection`, set `istio.io/rev`, restart. Only the restart moves a workload.
- Rolling back is the same three steps in reverse, because the old control plane is still running.

**From [Revision Tags](./course-03-revision-tags.md):**

- A revision tag, such as `prod`, is a call sign for a revision. Underneath it is another webhook, `istio-revision-tag-prod`.
- Label namespaces with the tag once. After that, `istioctl tag set prod --revision <name> --overwrite -y` and a restart move them.
- `istioctl tag list` shows each tag, its revision and the namespaces that follow it.

**From [Retiring The Old Revision](./course-04-retiring-the-old-revision.md):**

- Restart every workload onto the new revision first, then run `istioctl uninstall --revision default -y`.
- Never use `--purge` during a canary: it removes every revision and the shared CRDs.
- Check `istioctl proxy-status` and the namespace labels before you uninstall. Gateways move as their own step.

## Your missions

You proved the skill in a graded mission, right after the part that taught it:

| Mission | After the part | What you proved |
| --- | --- | --- |
| [Canary Upgrade With Revisions And Tags](./labs/lab-01/README.md) | Revision Tags | install a canary control plane, create a `prod` tag, and move a namespace through the tag |

If you skipped it, go back to it now.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. You install revision <code>1-30-5</code>. Which pods move to it?</summary>

None. Installing a revision only creates a second control plane. Pods move when their namespace is labelled for the revision and the pods are recreated.
</details>

<details>
<summary>2. Why is the revision called <code>1-30-5</code> and not <code>1.30.5</code>?</summary>

Revision names become part of Kubernetes object names, so they must be valid DNS labels. Dots are not allowed.
</details>

<details>
<summary>3. A namespace has both <code>istio-injection=enabled</code> and <code>istio.io/rev=1-30-5</code>. Which control plane injects its new pods?</summary>

The default one. The revision's webhook requires `istio-injection` to be absent, so only the default webhook matches. Remove `istio-injection`.
</details>

<details>
<summary>4. Which command tells you which control plane a proxy is connected to?</summary>

`istioctl proxy-status`. Its `ISTIOD` column names the control plane pod for each proxy.
</details>

<details>
<summary>5. Your namespaces carry <code>istio.io/rev=prod</code>. How do you roll the whole fleet back to the default revision?</summary>

`istioctl tag set prod --revision default --overwrite -y`, then restart the workloads. No namespace label changes.
</details>

<details>
<summary>6. Why must you restart the workloads before you uninstall the old revision?</summary>

Pods left on a removed control plane keep running on their last configuration, but get no more updates and no certificate renewal. They fail later in ways that look unrelated.
</details>

<details>
<summary>7. Why is <code>istioctl uninstall --purge</code> the wrong command during a canary?</summary>

It removes every revision, including the new one, and the shared CRDs. Name the revision instead: `istioctl uninstall --revision default -y`.
</details>

<details>
<summary>8. Why does the canary install use the <code>minimal</code> profile?</summary>

A canary needs a second control plane, not a second set of gateways. A full profile would create gateway Deployments that fight over the same names.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and the mission if it is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-013-playground-030-02
```

If `astrona list` also showed the mission, remove it the same way:

```sh
astrona destroy ats-013-lab-030-02
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.
