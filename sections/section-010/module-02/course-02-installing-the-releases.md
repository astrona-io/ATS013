# Installing The Three Releases

Astronaut, time to assemble the kits. You install the three Helm releases in order: the foundations (`istio-base`), mission control (`istiod`) and a spaceport arrival gate (`istio-ingressgateway`). Along the way you take apart the two flags and the one values file that carry all the real decisions. By the end you have a working control plane and an ingress gateway, installed the way a pipeline would install them.

## Namespaces first

Neither `base` nor `istiod` creates `istio-system`, and the gateway chart does not create its namespace either. Helm's `--create-namespace` flag works, but creating them yourself is worth the extra line. The namespace is where labels, quotas and network policies go, and if it exists before the install, those become a normal part of your setup instead of an afterthought.

<!-- astrona:playground:renew -->

```sh
kubectl create namespace istio-system
kubectl create namespace istio-ingress
```

## `base`: definitions, and nothing running

The first release lays the foundations. Here is the command:

```sh
helm install istio-base istio/base -n istio-system \
  --version 1.30.5 --set defaultRevision=default --wait
```

Three parts of that line each deserve a short explanation.

### `--version 1.30.5`

It pins the chart. Without it, Helm installs whatever is newest in the repository when you run it, so the same command two months apart installs two different Istio versions. On a production install it is not optional. It is also what makes a later upgrade a deliberate act, not a side effect of `helm repo update`.

### `--wait`

It makes Helm wait until the release's resources report ready, instead of returning as soon as the API server accepts them. `base` has no pods to wait for, so it is almost instant. Using `--wait` on all three installs is what stops a script racing ahead to `istiod` before the CRDs are really in place.

### `--set defaultRevision=default`

It tells the chart which control plane revision owns the injection webhook for namespaces with no revision named. A revision is a named mission control; the `default` one answers planets with the plain `istio-injection=enabled` order. Leave it out on a single control plane install and injection can fail later with no webhook willing to serve the namespace. That failure looks nothing like its cause.

### See it in your playground

Install `base`, then look at what it created:

```sh
helm install istio-base istio/base -n istio-system --version 1.30.5 --set defaultRevision=default --wait
helm ls -n istio-system
kubectl get crd | grep -c istio.io
kubectl -n istio-system get pods
```

Expect something like:

```text
NAME            NAMESPACE       REVISION    STATUS      CHART           APP VERSION
istio-base      istio-system    1           deployed    base-1.30.5     1.30.5

15
No resources found in istio-system namespace.
```

One deployed release, a two-digit number of CRDs, and no pods. `base` is pure definitions. That is exactly why installing `istiod` first fails: the kinds it needs would not exist yet.

## `istiod`: where configuration enters

The second release is mission control, and it is where your configuration enters. You write the order form for the kit first, as a file you can commit, then install with it.

### Write the values file

Save this as `istiod-values.yaml`:

```yaml
meshConfig:
  accessLogFile: /dev/stdout
  outboundTrafficPolicy:
    mode: ALLOW_ANY
pilot:
  autoscaleEnabled: false
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
global:
  proxy:
    resources:
      requests:
        cpu: 10m
        memory: 64Mi
```

### What the three keys do

The file has three top-level keys. Each one has a different audience, and its result shows up in a different place:

- **`meshConfig`** is the fleet's standing orders: mesh-wide behaviour such as access logging, the outbound traffic policy and tracing. The chart writes it word for word into a ConfigMap named `istio` in `istio-system`, under the key `mesh`. `istiod` reads that ConfigMap and passes the relevant parts to every proxy.
- **`pilot`** configures the control plane workload itself: replicas, autoscaling, resource requests, placement. `pilot` is the old name of the component that became `istiod`, which is why the key looks unfamiliar. It is the `istiod` Deployment.
- **`global.proxy`** is the standard kit every communications officer is issued: defaults for *every injected sidecar*. Its cost multiplies. A `10m` CPU request here is `10m` for each meshed pod, not `10m` in total.

These keys match the `IstioOperator` tree. `meshConfig` is `spec.meshConfig`, `pilot` is roughly `spec.components.pilot.k8s`, and `global.proxy` is `spec.values.global.proxy`. The Helm values file *is* the `spec.values` part of the tree, which is why both install methods use the same documentation.

### Install it

Apply it:

```sh
helm install istiod istio/istiod -n istio-system \
  --version 1.30.5 -f istiod-values.yaml --wait
```

Then check the result. Confirm that the values reached the cluster, not just the release:

```sh
kubectl -n istio-system get deploy istiod
kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | head -12
kubectl -n istio-system get deploy istiod -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}{"\n"}'
```

Expect something like:

```text
NAME     READY   UP-TO-DATE   AVAILABLE   AGE
istiod   1/1     1            1           48s

accessLogFile: /dev/stdout
defaultConfig:
  discoveryAddress: istiod.istio-system.svc:15012
  proxyMetadata: {}
...
outboundTrafficPolicy:
  mode: ALLOW_ANY

100m
```

The `mesh` key in the `istio` ConfigMap is the live `meshConfig`: not what you typed, but what the cluster runs. When a mesh-wide setting "is not working", this answers the first question clearly: did it ever arrive? The `100m` proves the `pilot` block reached the Deployment.

### What those checks do not prove

They do not prove that the proxies have received the setting. The ConfigMap is the control plane's input. `istioctl proxy-status` is how you check that `istiod` pushed it to the data plane. Keeping those two questions apart is the difference between a five-minute diagnosis and a lost afternoon.

## `gateway`: a release per edge

The third release is the arrival gate:

```sh
helm install istio-ingressgateway istio/gateway -n istio-ingress \
  --version 1.30.5 --wait
```

There is no values file here. The defaults are sensible, and everything interesting about a gateway (which ports, which hosts, which TLS certificates) is set at *runtime* through a `Gateway` resource, not at install time. The chart's job is to put an Envoy proxy and a Service in the namespace. What that proxy serves is a separate decision, made after the install.

### See it in your playground

Look at the gateway and where it lives:

```sh
kubectl -n istio-ingress get deploy,svc
kubectl -n istio-ingress get pod -l app=istio-ingressgateway \
  -o jsonpath='{.items[0].spec.containers[*].name}{"\n"}'
```

Expect something like:

```text
NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/istio-ingressgateway   1/1     1            1           35s

NAME                           TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
service/istio-ingressgateway   LoadBalancer   10.96.148.22   <pending>     15021:31...,80:31...,443:31...

istio-proxy
```

One container called `istio-proxy`: the same Envoy image a sidecar runs, deployed on its own. `EXTERNAL-IP <pending>` is expected on `kind`, which has no cloud load balancer. The Service still works through its node ports.

## Which settings belong at install time

Once you have a values file, one question keeps coming back: does this setting go in the chart values, or in a resource you apply later? The line is the same one `istioctl` draws:

| Install time (values file) | Runtime (Kubernetes resources) |
| --- | --- |
| Which components exist, and how many replicas | Which hosts a gateway serves (`Gateway`) |
| Control plane sizing and autoscaling | Routing and traffic splitting (`VirtualService`) |
| Mesh-wide defaults (`meshConfig`) | Per-workload logging and tracing (`Telemetry`) |
| Default sidecar resources | mTLS mode and authorization (`PeerAuthentication`, `AuthorizationPolicy`) |

Putting a setting on the wrong side of that line is not a syntax error. It turns a quick `kubectl apply` into a `helm upgrade`, with a control plane restart you did not need.

The values file is the `spec.values` tree under another name: `meshConfig` lands in a ConfigMap, `pilot` lands on the Deployment, and `global.proxy` multiplies by every meshed pod.

## Common pitfalls

> [!WARNING]
> **Leaving out `--version`.** Helm installs whatever the repository offers right now, so two runs a month apart install two different Istio versions.
>
> **Creating the namespace as an afterthought.** `helm install -n` does not create it unless you ask. `--create-namespace` or an earlier `kubectl create namespace` is part of the step.
>
> **Setting a mesh-wide value on the wrong release.** `meshConfig` belongs to `istiod`. Helm accepts it on `base` or `gateway` and it does nothing there.
>
> **Leaving `defaultRevision` unset when you meant to own the default.** The injection webhook needs a revision to point at.
>
> **Setting at install time what belongs in a runtime object.** Gateways, routing and policy are Istio objects you apply later, not chart values.
