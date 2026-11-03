# The components Block And k8s Settings

A profile decides which components run, but a real cluster needs more control: another replica count, a node selector, a different Service. This part shows where those settings live in an `IstioOperator` file. It starts with the live objects, then maps each one to the field that controls it.

## What the install created

An Istio install creates ordinary Kubernetes objects. List the ones in `istio-system`:

<!-- astrona:playground:renew -->

```sh
kubectl -n istio-system get deployment,service,hpa
```

You see the `istiod` Deployment and Service, the `istio-ingressgateway` Deployment and Service, and a `HorizontalPodAutoscaler` (HPA) for each Deployment. Every one of them is rendered by `istioctl` from the profile. When you want one of them to be different, you change it in the `IstioOperator` file and install again, never in the cluster.

## The entries under spec.components

The `components` block names the pieces of the installation. Print the one the `default` profile defines:

```sh
istioctl profile dump default --config-path components
```

The entries are:

- `base`: the CRDs and the cluster-wide objects.
- `pilot`: `istiod`, the control plane.
- `ingressGateways` and `egressGateways`: lists, because a cluster can run several gateways. Each entry has a `name`.
- `cni`: the Istio CNI node agent, used by the sidecar mode on request and always by ambient mode.
- `ztunnel`: the per-node proxy of ambient mode.

Each component has an `enabled` flag. `enabled: false` on a component that the profile turns on makes the install remove it, as the next install reconciles the cluster with the new render. For the lists, the `name` identifies the entry, so an overlay that names `istio-ingressgateway` changes the existing gateway instead of adding a second one.

## The k8s block

Under each component, `k8s` holds the settings for the Kubernetes objects of that component. The fields you need most are:

| Field | What it sets |
| --- | --- |
| `resources` | The CPU and memory requests and limits of the main container |
| `replicaCount` | The number of replicas of the Deployment |
| `hpaSpec` | The `HorizontalPodAutoscaler`: minimum and maximum replicas and the metrics |
| `nodeSelector`, `affinity`, `tolerations` | Where the pods are scheduled |
| `service` | The `Service` of the component: its type and ports (gateways) |
| `env` | Extra environment variables for the main container |
| `podAnnotations` | Annotations added to the pods |
| `overlays` | JSON-path style patches for any field the other keys do not reach |

Read the live Deployment and see where `resources` ends up:

```sh
kubectl -n istio-system get deployment istiod -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
```

The overlay `components.pilot.k8s.resources.requests.cpu` sets the `cpu` value you see in this output. The path in the file follows the structure of the live object.

## Render before you apply

`istioctl manifest generate` runs the render step of the install and prints the result. Use it to check an overlay before it touches the cluster. Save this as `istio-pilot.yaml`:

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  components:
    pilot:
      k8s:
        resources:
          requests:
            cpu: 250m
            memory: 1Gi
```

Render it and look for the new values:

```sh
istioctl manifest generate -f istio-pilot.yaml | grep -n -A3 'requests:'
```

The new `cpu: 250m` appears in the `istiod` Deployment. Nothing in the cluster changed, because the command only prints. The file `istio-pilot.yaml` is applied with `istioctl install -f istio-pilot.yaml -y` only when the render shows what you wanted.

You now know the components of an install and the `k8s` block that reshapes each of them. The gateway is the component where this matters most, because its Service decides whether traffic from outside can reach the mesh at all. The next part changes it.

## Common pitfalls

> [!WARNING]
> **Editing the live Deployment.** The next `istioctl install` renders the object again and overwrites the edit. Change the `IstioOperator` file.
>
> **Naming a gateway wrongly.** In `ingressGateways` the `name` selects the entry. A new name creates a second gateway.
>
> **Putting `resources` under `values`.** Component settings go under `components.<name>.k8s`. The `values` block holds chart values.
