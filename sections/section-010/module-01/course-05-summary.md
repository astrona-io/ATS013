# Wrap-Up: Mission Debrief

Well flown, astronaut. You have finished every part and the mission in this module. Before you move on, look back at what you learned, check yourself, and land the playground cleanly.

## What you learned

This module was about building mission control, `istiod`, with your launch console, `istioctl`, and about what that build leaves in the cluster.

**From [The Render-And-Apply Pipeline](./course-01-render-and-apply-pipeline.md):**

- `istioctl install` runs four stages: load the profile, overlay your files and flags, render plain Kubernetes objects, apply. Only the last stage touches the cluster.
- No operator runs in the cluster. The `IstioOperator` document is an input, and a hand edit of an installed object stays until the next install.
- `--set` always beats `-f`, and neither leaves a trace in the cluster. `istioctl manifest generate` prints the objects without applying them.
- `istioctl x precheck` checks the cluster (Kubernetes version, leftover CRDs, stale webhooks), not your YAML.

**From [Profiles And The Objects They Produce](./course-02-profiles-and-installed-objects.md):**

- A profile is a complete starting document. `default` has `istiod` and an ingress gateway, `demo` adds an egress gateway, `minimal` has `istiod` only, and `ambient` adds `istio-cni` and `ztunnel`.
- `istiod` is one pod with three jobs: xDS server, certificate authority and injection webhook backend.
- An install also creates a mutating webhook (`istio-sidecar-injector`), a validating webhook and the Istio CRDs. A gateway is just the `istio-proxy` image running on its own.

**From [Injection And The Version Triad](./course-03-injection-and-version-alignment.md):**

- Injection happens once, inside the API server, when a pod is created. The webhook selects pods by their namespace's labels.
- `istio-injection=enabled` changes only new pods. Existing pods need a restart, for example with `kubectl rollout restart deployment`.
- The client, the control plane and the data plane each have a version. The supported gap is one minor version. `istioctl version` and `istioctl proxy-status` show all of them.

**From [Reconciliation And Clean Removal](./course-04-reconciliation-and-removal.md):**

- A second install replaces the blueprint: components and fields it leaves out are removed or reset.
- Istio prunes only objects with its ownership labels for that revision. Hand-made objects and other revisions are left alone.
- `uninstall --revision` removes one control plane; `uninstall --purge` removes every revision and the CRDs. Namespace labels and existing sidecars survive both.

## Your missions

You proved the skills in a graded mission, right after the part that finished teaching them:

| Mission | After the part | What you proved |
| --- | --- | --- |
| [Install Istio With istioctl](./labs/lab-01/README.md) | Reconciliation And Clean Removal | install a `demo` control plane, bring a running workload into the mesh, and show that the versions agree |

If you skipped it, go back to it now.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. Which stages of <code>istioctl install</code> touch the cluster?</summary>

Only the last one, apply. Loading the profile, overlaying your files and flags, and rendering the objects all happen on your machine.
</details>

<details>
<summary>2. You run <code>istioctl install -f mine.yaml --set meshConfig.accessLogFile=/dev/stdout</code>, and <code>mine.yaml</code> sets a different value for the same field. Which one wins?</summary>

The `--set` value. `--set` flags always beat `-f` files, wherever they sit on the command line.
</details>

<details>
<summary>3. What is the only difference in objects between the <code>default</code> and <code>demo</code> profiles?</summary>

The egress gateway: the gateway itself, its secret-discovery configuration and its service account.
</details>

<details>
<summary>4. <code>istiod</code> is down. Does traffic between meshed pods stop at once?</summary>

No. Proxies keep running on the last configuration they received. What stops is change: no new configuration, no new certificates and no injection for new pods.
</details>

<details>
<summary>5. You label a namespace with <code>istio-injection=enabled</code>. Its pods still have one container. Why?</summary>

Injection only happens when a pod is created. Those pods existed before the label. Restart them and the new pods get the sidecar.
</details>

<details>
<summary>6. In <code>istioctl proxy-status</code>, a gateway shows <code>NOT SENT</code> under <code>RDS</code>. Is something broken?</summary>

No. `NOT SENT` means there is nothing of that kind to send. A gateway with no `Gateway` resource attached has no routes.
</details>

<details>
<summary>7. You installed <code>demo</code>, then ran <code>istioctl install --set profile=minimal -y</code>. What happened to the gateways?</summary>

They were deleted. The install makes the cluster match the new document, and `minimal` has no gateways.
</details>

<details>
<summary>8. You are running two control planes and want to remove the old one. Why not use <code>--purge</code>?</summary>

`--purge` removes every revision and the CRDs, so it would take the new control plane too. Use `istioctl uninstall --revision <name>` instead.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and the mission if it is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-013-playground-010-01
```

If `astrona list` also showed the mission, remove it the same way:

```sh
astrona destroy ats-013-lab-010-01
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.
