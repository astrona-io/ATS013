# Wrap-Up: Mission Debrief

Well flown, astronaut. You have finished every part and the mission in this module. Before you move on, look back at what you learned, check yourself, and land the playground cleanly.

## What you learned

This module built the same mission control as `istioctl`, but from Helm kits: three releases, a values file, and a logbook that lives in the cluster.

**From [The Chart Model And Its Ordering](./course-01-chart-model-and-ordering.md):**

- Istio ships five charts. Sidecar mode needs three: `istio/base`, `istio/istiod` and `istio/gateway`. Chart versions match Istio versions exactly.
- `base` comes first because it defines the CRDs that `istiod`'s objects use. A wrong order gives an API error that names the missing kind.
- A gateway is its own release, often in its own namespace. The release name becomes the Deployment name, the Service name and the `istio:` label.
- Helm values follow the same tree as `spec.values` in an `IstioOperator`.

**From [Installing The Three Releases](./course-02-installing-the-releases.md):**

- Create the namespaces first, pin every chart with `--version`, and use `--wait` on every install.
- `defaultRevision=default` on `base` tells the chart which control plane serves namespaces labelled `istio-injection=enabled`.
- In the values file, `meshConfig` lands in the `istio` ConfigMap, `pilot` lands on the `istiod` Deployment, and `global.proxy` sets defaults for every sidecar.
- Gateways, routing and policy are runtime objects, not chart values.

**From [Release State, Verification And Cleanup](./course-03-release-state-and-verification.md):**

- Each release revision is a `sh.helm.release.v1.*` Secret in the cluster. Deleting those Secrets deletes the history and the rollback path.
- `helm ls -A`, `helm history`, `helm get values` and `helm get values --all` read back what is installed.
- `deployed` only means the objects were applied. Injecting a pod and reading `istioctl proxy-status` prove the install works.
- `helm uninstall` leaves the CRDs, the namespace labels and every running sidecar in place.

## Your missions

You proved the skills in a graded mission, right after the part that finished teaching them:

| Mission | After the part | What you proved |
| --- | --- | --- |
| [Install Istio With Helm](./labs/lab-01/README.md) | Release State, Verification And Cleanup | install three pinned releases in order, set access logging from a values file, and bring a running workload into the mesh |

If you skipped it, go back to it now.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. You install <code>istio/istiod</code> before <code>istio/base</code>. What fails, and which component rejects it?</summary>

The install fails because the kinds `istiod`'s chart creates do not exist yet. The API server rejects them, with an error that names the missing resource and says to install the CRDs first.
</details>

<details>
<summary>2. You install the gateway chart as a release named <code>public-gateway</code>. What is its Deployment called?</summary>

`public-gateway`. The chart builds the Deployment name, the Service name and the pod labels from the release name.
</details>

<details>
<summary>3. Why should every <code>helm install</code> for Istio carry <code>--version</code>?</summary>

Without it, Helm installs whatever is newest in the repository at that moment, so the same command run on two different days can install two different Istio versions.
</details>

<details>
<summary>4. Where does a <code>meshConfig</code> value from your values file end up in the cluster?</summary>

In the `istio` ConfigMap in `istio-system`, under the key `mesh`. `istiod` reads it from there.
</details>

<details>
<summary>5. You set a <code>10m</code> CPU request under <code>global.proxy</code>. How much CPU does that request in total?</summary>

`10m` for each meshed pod, because `global.proxy` sets the default for every injected sidecar.
</details>

<details>
<summary>6. All three releases show <code>deployed</code>. Does that prove injection works?</summary>

No. It only means the objects were applied. Create a pod in a labelled namespace and check that it gets an `istio-proxy` container, then check `istioctl proxy-status`.
</details>

<details>
<summary>7. Where does Helm keep a release's values and history?</summary>

In the cluster, as Secrets of type `helm.sh/release.v1` named `sh.helm.release.v1.<release>.v<revision>`, in the release's namespace.
</details>

<details>
<summary>8. You uninstalled all three releases. Which Istio pieces are still in the cluster?</summary>

The Istio CRDs, the `istio-injection` labels on namespaces, and the sidecars in pods that were already running.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and the mission if it is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-013-playground-010-02
```

If `astrona list` also showed the mission, remove it the same way:

```sh
astrona destroy ats-013-lab-010-02
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.
