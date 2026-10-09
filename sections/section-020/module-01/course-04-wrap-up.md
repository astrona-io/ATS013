# Wrap-Up: Mission Debrief

Well flown, astronaut. You have finished every part and the mission in this module. Before you move on, look back at what you learned, check yourself, and land the playground cleanly.

## What you learned

This module was about the blueprint behind `istioctl install`: the `IstioOperator` document, and how each of its layers reaches the cluster.

**From [The Four Configuration Layers](./course-01-the-four-configuration-layers.md):**

- An `IstioOperator` document has four layers: `profile` (the stock blueprint), `components` (what is deployed and how big), `meshConfig` (mesh-wide behaviour) and `values` (a passthrough to the Helm charts).
- Sources merge in the order profile, then `-f` files, then `--set` flags, and the merge is per field, not per block.
- If `components` and `values` set the same thing, `components` wins. Prefer the structured field anyway.
- Plumbing belongs in the installation; traffic rules for one workload or namespace belong in runtime resources such as `VirtualService` or `Telemetry`.

**From [meshConfig: From File To ConfigMap To Proxy](./course-02-meshconfig-from-file-to-proxy.md):**

- A `meshConfig` setting travels from your file, to the `istio` ConfigMap in `istio-system`, to `istiod`, to every proxy through an xDS push.
- Check each stop in order: `istioctl validate` and `manifest generate`, the ConfigMap, `istioctl proxy-status`, then real traffic.
- `REGISTRY_ONLY` blocks every destination that is not in the mesh registry; the proxy answers an external call with `502`.
- A runtime resource can override a `meshConfig` default for one workload, and that is by design.

**From [Writing, Validating And Re-applying The Document](./course-03-writing-validating-reapplying.md):**

- Component lists are matched by `name`. A name that matches nothing adds a new, disabled entry and leaves the original running.
- Unknown fields are ignored, not rejected. `istioctl manifest generate -f` shows whether your change is really in the rendered result.
- Comparing the rendered `demo` profile with your file shows exactly what you changed.
- A second `istioctl install` makes the cluster match the new document, so anything you leave out reverts. Keep one file per control plane in version control.

## Your missions

You proved the skill in a graded mission, right after the part that taught it:

| Mission | After the part | What you proved |
| --- | --- | --- |
| [Customize An Istio Installation](./labs/lab-01/question.md) | Writing, Validating And Re-applying The Document | remove one gateway, size `istiod` and set two mesh-wide settings, then check each change where its layer lands |

If you skipped it, go back to it now.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. A task says "every sidecar should request 20m of CPU by default". Which layer do you use?</summary>

`values`, under `values.global.proxy.resources`. `components.pilot.k8s.resources` would size `istiod`, which is one Deployment, not the sidecars.
</details>

<details>
<summary>2. You set only <code>components.pilot.k8s.resources.requests.cpu</code>. Does the rest of the profile's <code>pilot</code> block disappear?</summary>

No. The merge is per field. Only that one leaf is replaced; everything else in `components.pilot` comes from the profile as before.
</details>

<details>
<summary>3. You turned on access logging. Where do you look first to see whether the setting reached the cluster?</summary>

In the `istio` ConfigMap in `istio-system`, under its `mesh` key: `kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}'`. If `accessLogFile` is not there, the problem is in your file or the install, not in the proxies.
</details>

<details>
<summary>4. After <code>REGISTRY_ONLY</code>, a meshed pod gets <code>502</code> when it calls <code>http://example.com</code>. Is the mesh broken?</summary>

No. The setting is working. `REGISTRY_ONLY` blocks hosts that are not in the mesh registry, and the sidecar answers with `502`. A `ServiceEntry` makes a specific external host reachable again.
</details>

<details>
<summary>5. Your file sets <code>name: istio-egress-gateway</code> with <code>enabled: false</code>. The install succeeds, but the egress gateway still runs. Why?</summary>

Component lists are matched by `name`, and the profile's gateway is called `istio-egressgateway`. Your entry matched nothing, so it became a second, disabled gateway, and the original kept running.
</details>

<details>
<summary>6. <code>istioctl validate -f</code> says your file is valid. Is that enough before you apply it?</summary>

No. It checks the schema, not whether your change matched anything. Run `istioctl manifest generate -f` and find your change in the rendered result.
</details>

<details>
<summary>7. You installed your custom file. A colleague then runs <code>istioctl install --set profile=demo -y</code>. What happens to your changes?</summary>

They revert. The egress gateway comes back, access logging disappears and the CPU request returns to the profile's value, because `istioctl install` makes the cluster match the document it was given.
</details>

<details>
<summary>8. You need access logging for one workload only. Do you change <code>meshConfig</code>?</summary>

No. `meshConfig` is mesh-wide, gateways included. Logging for one workload is a runtime `Telemetry` resource, and it needs no new install.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and the mission if it is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-013-playground-020-01
```

If `astrona list` also showed the mission, remove it the same way:

```sh
astrona destroy ats-013-lab-020-01
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.
