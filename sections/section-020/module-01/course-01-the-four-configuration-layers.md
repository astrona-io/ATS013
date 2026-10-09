# The Four Configuration Layers

Every installation setting in Istio lives in one of four places in an `IstioOperator` document. An `IstioOperator` document is the blueprint you hand to `istioctl install`: it describes the whole Istio installation you want. The four places are not four ways of writing the same thing. They take effect at different times, on different objects.

This part sorts out which is which, so you always know where a setting belongs.

## The document, and what each key owns

Here is the empty shape of the blueprint. Each top-level key under `spec` is one layer:

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: demo          # 1. the baseline document
  components: {}         # 2. which components exist + their Kubernetes settings
  meshConfig: {}         # 3. mesh-wide runtime behaviour
  values: {}             # 4. raw Helm values passthrough
```

Read it from top to bottom. `profile` picks a stock blueprint from the shipyard catalogue. `components` and `meshConfig` are the supported, structured ways to change it. `values` is the escape hatch for anything the structured layers do not cover.

### `spec.components`: what is deployed, and how big

The `components` layer turns a component on or off, and configures it as a Kubernetes workload. For example, `components.egressGateways[0].enabled: false` removes a Deployment, and `components.pilot.k8s.resources.requests.cpu: 100m` changes one field on a pod template.

Each component name maps to objects you can see in `istio-system`:

| Key | Object in the cluster |
| --- | --- |
| `components.base` | The CRDs and cluster-scoped resources |
| `components.pilot` | The `istiod` Deployment (historical name) |
| `components.ingressGateways[]` | One Deployment + Service per list entry |
| `components.egressGateways[]` | Same, for egress |
| `components.cni`, `components.ztunnel` | The ambient DaemonSets |

A CRD (Custom Resource Definition) is a new form the cluster's registry office learns to accept, for example a form for a `VirtualService`. `pilot` is the old name of the part that became `istiod`, mission control.

Under any component, `k8s:` is the fixed sub-key for Kubernetes settings: `resources`, `replicaCount`, `hpaSpec`, `nodeSelector`, `service` and `serviceAnnotations`. If a setting would be a field on a Deployment or a Service, it goes under `k8s:`.

### `spec.meshConfig`: how deployed things behave

The `meshConfig` layer holds the fleet's standing orders: where to write access logs and in what format, which outbound destinations are allowed, tracing, and default proxy settings. Nothing here changes *what* is deployed. It changes what the deployed proxies (the communications officers on each ship) do.

### `spec.values`: the passthrough

The `values` layer is handed straight to the Helm charts that `istioctl` uses inside. It uses exactly the same tree as a Helm values file for the `istiod` chart. Use it when a chart offers a setting that the structured layers do not.

## When two layers could set the same thing

`components` and `values` overlap, because `components` is a structured front end over part of what `values` can reach. Two rules settle it:

1. **Prefer the structured field.** Istio promises to keep `components` and `meshConfig` stable. `values` is a passthrough to the inside of the charts, and it can change more between versions.
2. **When both set the same thing, `components` wins.** It is applied after the `values` overlay while the document is rendered. Do not rely on this. Setting one thing in two places is how a future reader ends up changing the copy that does nothing.

In practice: use `values` only for settings with no `components` or `meshConfig` field, and leave a comment saying why.

## How the layers merge

`istioctl install` builds one final document from several sources before it renders anything. This section shows that order, and the one rule about how fields combine.

### The order of the sources

The sources are read in a fixed order, and a later source wins:

```mermaid
flowchart TD
    P["profile"] -->|"base document"| O["-f overlays, in order"]
    O --> F["--set flags"]
    F -->|"merged"| M["one IstioOperator"]
    M -->|"rendered"| R["Kubernetes manifests"]
```

The diagram shows that the profile is the base, your `-f` files go on top of it in the order you give them, and `--set` flags go on top of everything.

Inside one document, the four layers are not a priority stack. They configure different things, and all of them are applied. Only `profile` behaves like a base that the rest overrides.

### The merge is per field

Merging happens **one field at a time, not one block at a time**. Setting `components.pilot.k8s.resources.requests.cpu` does not throw away the rest of `components.pilot` from the profile. It replaces that one leaf, and everything else stays.

Lists are the exception, and it is an important one: list entries are matched by their `name`, and an entry whose name matches nothing is added as a new entry.

### See it in your playground

`istioctl manifest generate` runs every rendering stage of `istioctl install` and prints the Kubernetes objects, without touching the cluster. Older Istio had an `istioctl profile dump` command for this; it was removed, and `manifest generate` replaced it. Count the kinds of object the `demo` profile produces, and list its gateways:

<!-- astrona:playground:renew -->

```sh
istioctl manifest generate --set profile=demo | grep -E '^kind:' | sort | uniq -c | sort -rn | head -6
istioctl manifest generate --set profile=demo | grep -E '^  name: istio-(ingress|egress)gateway$' | sort -u
```

Expect something like:

```text
  15 kind: CustomResourceDefinition
   4 kind: ServiceAccount
   3 kind: Service
   3 kind: RoleBinding
   3 kind: Role
   3 kind: Deployment

  name: istio-egressgateway
  name: istio-ingressgateway
```

Three Deployments (`istiod` and both gateways) are the `components` layer made visible, and the fifteen CRDs are the `base` component. Nothing here is `meshConfig`: that layer creates no objects of its own. It is written into the contents of a ConfigMap instead.

## The line between installation and runtime

Before you choose a layer, check that the requirement belongs in the installation at all. This section gives you the test and shows what the untouched cluster sets.

### Plumbing or traffic?

The test is simple: does the setting describe the mesh's plumbing, or the traffic flowing through it? Plumbing goes in the `IstioOperator` document. Traffic rules are runtime resources: ordinary Kubernetes objects you apply and delete at any time, which `istiod` picks up within seconds.

| Belongs in `IstioOperator` | Belongs in a runtime resource |
| --- | --- |
| Whether an egress gateway exists | Which external hosts are reachable (`ServiceEntry`) |
| `istiod` replicas, CPU, autoscaling | Retries and timeouts for one service (`VirtualService`) |
| Mesh-wide access logging (`meshConfig`) | Access logging for one workload (`Telemetry`) |
| Default sidecar resource requests | mTLS mode for a namespace (`PeerAuthentication`) |
| Which trust domain the mesh uses | Who may call what (`AuthorizationPolicy`) |

Two things follow from this. First, a runtime change takes effect in seconds with no control plane restart, while an installation change runs the install again and rolls `istiod`. Picking the heavy tool when the light one exists is a risk you create yourself.

Second, installation settings are **mesh-wide by design**. `meshConfig` applies to every proxy, gateways included. If a requirement is really for one namespace or one workload, the installation layer cannot express it. Forcing it there changes behaviour for workloads nobody asked you to touch.

### See it in your playground

Check what the untouched `demo` profile sets for access logging and outbound traffic, and how much CPU each Deployment requests:

```sh
kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep -E 'accessLogFile|outboundTrafficPolicy' || echo '(neither key is present)'
kubectl -n istio-system get deploy -o custom-columns='NAME:.metadata.name,CPU-REQ:.spec.template.spec.containers[0].resources.requests.cpu'
```

Expect something like:

```text
(neither key is present)

NAME                   CPU-REQ
istio-egressgateway    10m
istiod                 500m
istio-ingressgateway   10m
```

The missing keys mean something: the stock `demo` profile sets neither `accessLogFile` nor `outboundTrafficPolicy`, so the built-in defaults apply. When those two keys appear later, you know your own document took effect. The CPU requests come from the profile's `components.*.k8s.resources` blocks: a `components` setting, visible on an ordinary Deployment.

In short: `components` decides what exists and how big, `meshConfig` decides how it behaves, and `values` is the escape hatch. None of them is the right place for something a runtime resource can express.

## Common pitfalls

> [!WARNING]
> **Setting a runtime concern at install time.** Routing, policy and per-workload behaviour are objects you apply to a running mesh, not installation fields.
>
> **Expecting a merge to replace a whole block.** The merge is per field, so a partial overlay leaves the rest of the profile in place.
>
> **Putting a value in the wrong layer.** `meshConfig` is mesh-wide; component settings are per component. Both are accepted, but only the right one takes effect.
>
> **Losing the overlay.** The merged document exists only during the render, so the file you passed is the only record of what you chose.
