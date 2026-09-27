# Part 1 — The Chart Model And Its Ordering

> Prerequisite: [the module landing page](./course.md). Next: [Part 2 — Installing The Three Releases](./course-02-installing-the-releases.md).

Before running anything, settle what Istio's Helm packaging actually is. "Install Istio with Helm" is three commands rather than one, in an order that is not negotiable, producing releases in two different namespaces. Each of those facts has a mechanical reason, and knowing the reasons is what lets you debug the install rather than retry it.

## Five charts, three of them for sidecar mode

A full sidecar-mode install is these commands, in this order:

```text
helm install istio-base           istio/base     -n istio-system
helm install istiod               istio/istiod   -n istio-system
helm install istio-ingressgateway istio/gateway  -n istio-ingress
```

The published charts and their jobs:

| Chart | Installs | Runs pods? |
| --- | --- | --- |
| `istio/base` | CRDs and cluster-scoped resources (cluster roles, bindings) | No |
| `istio/istiod` | The control plane Deployment, plus both webhook configurations | Yes |
| `istio/gateway` | One Envoy gateway Deployment and Service per release | Yes |
| `istio/cni` | The node-level traffic redirection DaemonSet | Yes — ambient, or sidecar mode without init containers |
| `istio/ztunnel` | The per-node L4 proxy DaemonSet | Yes — ambient only |

The last two belong to section 040. For a classic sidecar install, three is the whole list.

Chart versions track Istio releases exactly: chart `1.30.5` installs Istio `1.30.5`. That one-to-one mapping is what makes `--version 1.30.5` a meaningful pin, and it is why the repo lists `CHART VERSION` and `APP VERSION` as the same string.

> [!TIP]
> **Try it — see the charts and how they are versioned**
>
> ```sh
> helm search repo istio --versions | head -8
> helm show chart istio/base | head -6
> ```
>
> Expect something like:
>
> ```text
> NAME                    CHART VERSION   APP VERSION     DESCRIPTION
> istio/base              1.30.5          1.30.5          Helm chart for deploying Istio cluster resources
> istio/cni               1.30.5          1.30.5          Helm chart for Istio CNI components
> istio/gateway           1.30.5          1.30.5          Helm chart for deploying Istio gateways
> istio/istiod            1.30.5          1.30.5          Helm chart for istio control plane
> istio/ztunnel           1.30.5          1.30.5          Helm chart for Istio ztunnel components
> ```
>
> Five charts, versioned in lockstep. Note there is no umbrella chart that pulls the others in as dependencies — Istio deliberately does not ship one, because the pieces have different lifecycles and different owners in a real organisation.

## The ordering is a dependency, not a convention

Why `base` first: the `istiod` chart's templates create objects of kinds that `base` defines. A `CustomResourceDefinition` teaches the API server what a kind *is*; until it exists, any object of that kind is rejected — not by Helm, but by the API server, with an error naming the missing resource.

That is the important distinction. Getting the order wrong does not produce a Helm dependency warning. It produces an API error that reads like a broken chart:

```text
Error: INSTALLATION FAILED: unable to build kubernetes objects from release manifest:
resource mapping not found for name: "istio-validator-istio-system" ...
ensure CRDs are installed first
```

The final clause is the whole diagnosis. Read the kind in the error before assuming anything else is wrong.

Why `gateway` after `istiod`: a gateway pod is an Envoy that fetches its entire configuration from the control plane over xDS. Started with no control plane to reach, it comes up and sits there with an empty configuration — not crash-looping, just useless. It will recover when `istiod` appears, so this ordering is softer than the first one, but installing into a working control plane means the gateway is serving from the moment it is ready.

```text
  base        defines the kinds
    │         (CRDs, cluster roles)
    ▼
  istiod      creates objects OF those kinds
    │         (webhook configs), and becomes the xDS source
    ▼
  gateway     is an xDS client with nothing to do until istiod exists
```

## Why a gateway is its own release

There is no flag on the control plane chart that says "also give me an ingress gateway". This is a deliberate packaging decision with three consequences worth knowing.

**A gateway is a separate blast radius.** It is an internet-facing workload with its own Service, its own scaling characteristics and its own failure modes. `istio-system` holds the cluster's security-critical control plane and its certificate authority. Separating them means you can grant a team permission to manage their gateway — scale it, change its Service type, restart it — without granting them anything in `istio-system`.

**You can have as many as you need.** Installing the same chart twice under two release names in two namespaces gives you two independent gateways. Splitting public from internal traffic, or giving each team its own edge, is a second `helm install` rather than a different architecture.

**The release name becomes the object name.** The chart derives the Deployment name, the Service name and the pod labels from the release name. That matters because a `Gateway` resource you write later selects a gateway *workload by its labels* — so the release name is not cosmetic, it is part of the contract your traffic configuration depends on.

> [!TIP]
> **Try it — read the name the chart would use**
>
> ```sh
> helm template my-edge istio/gateway -n istio-ingress \
>   | grep -E '^kind:|^  name:|    app:|    istio:' | head -20
> ```
>
> Expect something like:
>
> ```text
> kind: ServiceAccount
>   name: my-edge
> kind: Deployment
>   name: my-edge
>     app: my-edge
>     istio: my-edge
> kind: Service
>   name: my-edge
>     app: my-edge
>     istio: my-edge
> ```
>
> `helm template` renders locally without touching the cluster — the Helm equivalent of `istioctl install --dry-run`. Every name and label here came from the release name `my-edge`. Change the release name and every one of them changes with it, including the `istio:` label a `Gateway` resource selects on.

## Where the value tree comes from

One more structural fact, because it saves learning the same thing twice. Chart values map onto the **same tree** as `spec.values` in an `IstioOperator`. `meshConfig.accessLogFile` is `meshConfig.accessLogFile` whether you write it in a Helm values file or an `IstioOperator` document.

That is not a coincidence: `istioctl install` renders the Istio charts internally. The two install methods are two front ends over one templating layer, which is why knowledge transfers between them — and also why running both against one cluster produces two owners of identical objects.

> *Istio ships as separate charts because its pieces have separate lifecycles; the install order is the CRD dependency, not a style rule.*

## Reference

- [Install with Helm](https://istio.io/v1.30/docs/setup/install/helm/) — the official three-chart procedure.
- [Istio Helm charts on Artifact Hub](https://artifacthub.io/packages/search?repo=istio) — published versions and their values schemas.
- [Installing gateways](https://istio.io/v1.30/docs/setup/additional-setup/gateway/) — the gateway chart's options and the labels it applies.
- `helm template --help` — rendering a chart locally before it reaches a cluster.
