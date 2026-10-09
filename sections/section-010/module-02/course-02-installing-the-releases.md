# Installing The Three Releases

A Helm install of Istio is three commands, but most of the real decisions sit in two flags and one values file. If you get them wrong, the install still succeeds today and causes trouble months later: a different Istio version on the next run, injection that silently does not happen, or a mesh setting that never reached the proxies. In this part you install the three Helm releases in order: the definitions (`istio-base`), the control plane (`istiod`) and an ingress gateway (`istio-ingressgateway`). By the end you have a working control plane and an ingress gateway, installed the way a pipeline would install them.

## Namespaces first

The charts install into namespaces, but they do not create them. Neither `base` nor `istiod` creates `istio-system`, and the gateway chart does not create its namespace either. Helm's `--create-namespace` flag works, but creating the namespaces yourself is worth the extra line. The namespace is where labels, quotas and network policies go. If it exists before the install, those become a normal part of your setup instead of an afterthought.

Create both namespaces:

<!-- astrona:playground:renew -->

```sh
kubectl create namespace istio-system
kubectl create namespace istio-ingress
```

## base: definitions, and nothing running

With the namespaces in place, the first release installs the definitions. The install command carries three options, and each one prevents a different problem.

`--version 1.30.5` pins the chart. Without it, Helm installs whatever is newest in the repository when you run it, so the same command two months apart installs two different Istio versions. On a production install it is not optional. It also makes a later upgrade a deliberate act, not a side effect of `helm repo update`.

`--wait` makes Helm wait until the release's resources report ready, instead of returning as soon as the API server accepts them. `base` has no pods to wait for, so it returns almost at once. Using `--wait` on all three installs stops a script from racing ahead to `istiod` before the CRDs (Custom Resource Definitions, which add the Istio object kinds to the API server) are really in place.

`--set defaultRevision=default` tells the `base` chart which control plane revision checks Istio configuration by default. A **revision** is a named installation of the control plane; several revisions can run side by side during an upgrade. With this value, the chart creates the `istiod-default-validator` validating webhook configuration: the API server sends every new or changed Istio object without a revision label, for example a `VirtualService`, to the `istiod` Service for a check before it stores it. `default` is already the chart's own default value, so the flag makes the choice visible rather than changing it. Sidecar injection for namespaces labelled `istio-injection=enabled` does not come from this value; the `istiod` chart creates that webhook.

Install `base`, then look at what it created. `helm ls` lists the releases in a namespace, and the last two commands count the Istio CRDs and list the pods:

```sh
helm install istio-base istio/base -n istio-system --version 1.30.5 --set defaultRevision=default --wait
helm ls -n istio-system
kubectl get crd | grep -c istio.io
kubectl -n istio-system get pods
```

The output looks like this (shortened):

```text
NAME            NAMESPACE       REVISION    STATUS      CHART           APP VERSION
istio-base      istio-system    1           deployed    base-1.30.5     1.30.5

15
No resources found in istio-system namespace.
```

There is one deployed release, fifteen CRDs and no pods. `base` contains only definitions. That is exactly why installing `istiod` first fails: the kinds it needs would not exist yet.

## istiod: where configuration enters

The definitions are in place, so the control plane can follow. The second release is where your own configuration enters. You write the settings first, as a file you can commit to Git, and then install with it.

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

The file has three top-level keys. Each one configures a different thing, and its result shows up in a different place in the cluster:

- **`meshConfig`** holds mesh-wide behaviour, such as access logging, the outbound traffic policy and tracing. The chart writes it word for word into a ConfigMap named `istio` in `istio-system`, under the key `mesh`. `istiod` reads that ConfigMap and passes the relevant parts to every proxy.
- **`pilot`** configures the control plane workload itself: replicas, autoscaling, resource requests and placement. `pilot` is the old name of the component that became `istiod`, which is why the key looks unfamiliar. It is the `istiod` Deployment.
- **`global.proxy`** sets the defaults for *every injected sidecar proxy*. Its cost multiplies: a `10m` CPU request here is `10m` for each pod in the mesh, not `10m` in total.

These keys match the `IstioOperator` tree. `meshConfig` is `spec.meshConfig`, `pilot` is roughly `spec.components.pilot.k8s`, and `global.proxy` is `spec.values.global.proxy`. The Helm values file *is* the `spec.values` part of the tree, which is why both install methods share the same documentation.

Apply it:

```sh
helm install istiod istio/istiod -n istio-system \
  --version 1.30.5 -f istiod-values.yaml --wait
```

Then check the result. These commands confirm that the values reached the cluster, not just the Helm release. The first shows the Deployment, the second prints the live mesh configuration, and the third reads the CPU request on the `istiod` container:

```sh
kubectl -n istio-system get deploy istiod
kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | head -12
kubectl -n istio-system get deploy istiod -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}{"\n"}'
```

The output looks like this (shortened):

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

The `mesh` key in the `istio` ConfigMap is the live `meshConfig`: not what you typed, but what the cluster runs. When a mesh-wide setting "is not working", this answers the first question: did the setting ever arrive? The `100m` proves that the `pilot` block reached the Deployment.

These checks do not prove that the proxies received the setting. The ConfigMap is the input to `istiod`. `istioctl proxy-status`, which lists every proxy and whether it accepted the latest configuration from `istiod`, is how you check that `istiod` pushed it to the data plane. Keeping those two questions apart turns a long search into a short one.

## gateway: one release per edge

The control plane now runs, so the gateway has something to connect to. The third release installs it:

```sh
helm install istio-ingressgateway istio/gateway -n istio-ingress \
  --version 1.30.5 --wait
```

There is no values file here. The defaults are sensible, and everything interesting about a gateway (which ports, which hosts, which TLS certificates) is set at *runtime* through a `Gateway` resource, not at install time. The chart's job is to put an Envoy proxy and a Service in the namespace. What that proxy serves is a separate decision, made after the install.

Look at the gateway and where it lives. The second command prints the names of the containers in the gateway pod:

```sh
kubectl -n istio-ingress get deploy,svc
kubectl -n istio-ingress get pod -l app=istio-ingressgateway \
  -o jsonpath='{.items[0].spec.containers[*].name}{"\n"}'
```

The output looks like this (shortened):

```text
NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/istio-ingressgateway   1/1     1            1           35s

NAME                           TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
service/istio-ingressgateway   LoadBalancer   10.96.148.22   <pending>     15021:31...,80:31...,443:31...

istio-proxy
```

The pod has one container called `istio-proxy`: the same Envoy image a sidecar runs, deployed on its own. `EXTERNAL-IP <pending>` is expected on `kind`, which has no cloud load balancer. The Service still works through its node ports.

## Which settings belong at install time

With a values file in hand, one question keeps coming back: does this setting go in the chart values, or in a resource you apply later? The line is the same one `istioctl` draws:

| Install time (values file) | Runtime (Kubernetes resources) |
| --- | --- |
| Which components exist, and how many replicas | Which hosts a gateway serves (`Gateway`) |
| Control plane sizing and autoscaling | Routing and traffic splitting (`VirtualService`) |
| Mesh-wide defaults (`meshConfig`) | Per-workload logging and tracing (`Telemetry`) |
| Default sidecar resources | mTLS (mutual TLS) mode and authorization (`PeerAuthentication`, `AuthorizationPolicy`) |

Putting a setting on the wrong side of that line is not a syntax error. It turns a quick `kubectl apply` into a `helm upgrade`, with a control plane restart you did not need.

You now know how to install the three releases in order, why each install carries `--version` and `--wait`, and where each part of the values file lands: `meshConfig` in the `istio` ConfigMap, `pilot` on the `istiod` Deployment, and `global.proxy` on every sidecar. The open question is how to read back what Helm applied, and how to prove that the mesh really works.

## Common pitfalls

> [!WARNING]
> **Leaving out `--version`.** Helm installs whatever the repository offers right now, so two runs a month apart install two different Istio versions.
>
> **Creating the namespace as an afterthought.** `helm install -n` does not create it unless you ask. `--create-namespace` or an earlier `kubectl create namespace` is part of the step.
>
> **Setting a mesh-wide value on the wrong release.** `meshConfig` belongs to `istiod`. Helm accepts it on `base` or `gateway`, and it does nothing there.
>
> **Setting `defaultRevision` to an empty value.** The `base` chart then creates no `istiod-default-validator` webhook, so Istio objects without a revision label are stored without a check, and a typo in a `VirtualService` gives no error.
>
> **Reading the ConfigMap as proof that the proxies have the setting.** The ConfigMap is the input to `istiod`. `istioctl proxy-status` shows whether `istiod` pushed it.
>
> **Setting at install time what belongs in a runtime object.** Gateways, routing and policy are Istio objects you apply later, not chart values.
