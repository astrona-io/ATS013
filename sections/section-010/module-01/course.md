# Install Istio With istioctl

<!-- astrona:playground -->
> [!NOTE]
> 🧪 **Hands-on playground for this module** — a clean, throwaway machine to explore on. No task, no grading. Folder: [`playground/`](https://github.com/astrona-io/ATS013/tree/main/sections/section-010/module-01/playground)
>
> ```sh
> astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-010/module-01/playground
> astrona destroy ats-013-playground-010-01
> ```

Every other thing Istio does — routing, mutual TLS, authorization, telemetry — sits on top of one control plane process called `istiod`. This module is about getting that process onto a cluster with the `istioctl` CLI, seeing exactly what it created, and taking it away again cleanly.

The command is one line. What makes it worth four parts is that `istioctl install` is *declarative*: it does not "add Istio", it renders a document and reconciles the cluster to match it. Almost every surprise people hit later — a second install that removed a gateway, a namespace label that changed nothing, an uninstall that left the cluster dirty — is that one sentence, unpacked.

## How this module is organised

1. **[Part 1 — The Render-And-Apply Pipeline](./course-01-render-and-apply-pipeline.md)** — what `istioctl install` does on your machine before anything reaches the cluster, why no operator pod exists, and what `istioctl x precheck` actually inspects.
2. **[Part 2 — Profiles And The Objects They Produce](./course-02-profiles-and-installed-objects.md)** — profiles as documents rather than presets, reading their real definitions, and an inventory of the control plane, webhooks, CRDs and gateways an install creates.
3. **[Part 3 — Injection And The Version Triad](./course-03-injection-and-version-alignment.md)** — how a pod gets a sidecar, why labelling a namespace changes nothing on its own, and how to read `istioctl proxy-status` when versions disagree.
4. **[Part 4 — Reconciliation And Clean Removal](./course-04-reconciliation-and-removal.md)** — what a second install does to settings you left out, how Istio decides what to prune, and the difference between `--revision` and `--purge`.

## Learning objectives

After this module you can:

- Describe the stages `istioctl install` runs through, and explain why no operator pod is reconciling your `IstioOperator` afterwards.
- List what `default`, `demo`, `minimal` and `ambient` each install, and compare two of them by diffing rendered manifests.
- Name the control plane, webhook, CRD and gateway objects an install creates, and say what each is for.
- Enable sidecar injection for a namespace, explain why existing pods are unaffected, and prove a new pod received a proxy.
- Diagnose client / control-plane / data-plane version mismatch from `istioctl version` and `istioctl proxy-status`.
- Predict what a second `istioctl install` does to settings the new document omits, and remove Istio so that the next install starts clean.

## Before you start

You should be comfortable with `kubectl` against a cluster you have admin rights on — namespaces, Deployments, and reading a pod spec. No prior Istio experience is assumed.

The playground gives you a single-node `kind` cluster with **`istioctl` 1.30.5 already on your PATH** and **no Istio installed at all**: no `istio-system` namespace, no CRDs, no webhooks. Everything in these parts runs from your normal shell with `kubectl` already pointed at the cluster. Confirm the binary before you start:

```sh
istioctl version --remote=false
```

If that prints `command not found`, the installer fell back to your home directory — run `export PATH="$HOME/.local/bin:$PATH"` and try again.

## Where this fits

`istioctl` is one of two supported ways to install Istio; Helm is the other, and it is the subject of the next module. They install the same control plane and are configured through the same value tree, but they are different owners of the same objects — a cluster should be managed by one or the other, never both. Choose `istioctl` when a human runs the install; choose Helm when a pipeline or an ArgoCD `Application` does. The ICA curriculum item says "istioctl **or** Helm" because you are expected to be fluent in both.
