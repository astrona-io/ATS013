# Part 2 — Profiles And The Objects They Produce

> Prerequisite: [Part 1 — The Render-And-Apply Pipeline](./course-01-render-and-apply-pipeline.md). Next: [Part 3 — Injection And The Version Triad](./course-03-injection-and-version-alignment.md).

Part 1 established that stage 1 of the pipeline loads a profile. This part is about what a profile actually *is* — a document you can read, diff and override, not a preset with hidden behaviour — and then about the objects that come out the other end. By the end you should be able to answer "what did that install put in my cluster?" without guessing.

## A profile is a document, not a setting

A **profile** is a named, built-in `IstioOperator` document, compiled into the `istioctl` binary. Picking `demo` is not selecting a mode; it is choosing a starting YAML file that you then deviate from.

The four you should be able to describe from memory:

| Profile | Installs | Typical use |
| --- | --- | --- |
| `default` | `istiod` + ingress gateway | Production starting point |
| `demo` | `istiod` + ingress **and** egress gateway, verbose telemetry | Learning and demos; not sized for production |
| `minimal` | `istiod` only | You supply gateways separately |
| `ambient` | `istiod` + `istio-cni` + `ztunnel` | Sidecar-less ambient mode (section 040) |

One command turns that table from something memorised into something checkable:

- **`istioctl manifest generate`** runs stages 1–3 of the pipeline and stops, printing the Kubernetes objects the install *would* apply. `--set profile=<name>` renders a built-in profile; `-f <file>` renders your own document.

Older Istio had a `istioctl profile` command family — `list`, `dump`, `diff` — that printed the effective `IstioOperator` instead. **Those subcommands were removed**, and `manifest generate` is what replaced them. If you are following material written for an older release, that is the substitution to make, and the output is arguably more useful: it shows the objects that will exist rather than a merged YAML document.

Because the output is a manifest, comparing two profiles is an ordinary `diff` of two renders. Comparing the *object names* rather than the whole YAML keeps the answer to one screen.

> [!TIP]
> **Try it — what actually separates `default` from `demo`**
>
> ```sh
> diff <(istioctl manifest generate --set profile=default | grep '^  name: ' | sort -u) \
>      <(istioctl manifest generate --set profile=demo    | grep '^  name: ' | sort -u)
> ```
>
> Expect something like:
>
> ```text
> 5a6,8
> >   name: istio-egressgateway
> >   name: istio-egressgateway-sds
> >   name: istio-egressgateway-service-account
> ```
>
> Three objects, all of them the egress gateway and the ServiceAccount and secret-discovery config that come with it. `demo` is not a different product — it is `default` plus one component, and that component is something you could enable or disable yourself, which is exactly what the customisation module in section 020 has you do.

There is no longer a command that lists the available profile names. They are documented with the release, and they also ship as YAML under `manifests/profiles/` in the full release bundle (the istioctl-only download does not include them). In practice you learn the four that matter and let the CLI tell you when a name is wrong:

> [!TIP]
> **Try it — how a bad profile name fails**
>
> ```sh
> istioctl manifest generate --set profile=production
> ```
>
> Expect something like:
>
> ```text
> Error: merge inputs: profile "production" not found: open profiles/production.yaml: file does not exist
> ```
>
> The error names the file it looked for, which tells you profiles really are documents on disk rather than modes built into the binary. Beyond the four in the table there are a few more: `empty` installs nothing and exists as a base for a fully hand-written document, `remote` and `external` configure a cluster whose control plane lives elsewhere, and `preview` carries features not yet in `default`.

## The control plane: one pod, three jobs

Installing `demo` produces three kinds of running workload and two kinds of cluster-scoped definition. Start with the one that matters most.

**`istiod`** is a Deployment in the `istio-system` namespace, normally one pod. That single process does three separate jobs that are worth naming individually, because different failures point at different ones:

- **xDS server.** It computes each proxy's configuration and pushes it over the xDS protocol. When a routing rule is applied but not taking effect, this is the job you are debugging.
- **Certificate authority.** It signs the workload certificates that make mutual TLS possible, and renews them on a cycle. When workloads start failing hours after an incident rather than immediately, this is usually why.
- **Injection webhook backend.** The mutating webhook configuration points *at* `istiod`; the actual decision about what to add to a pod is made by this process. Part 3 covers that path.

Because it is one process, losing `istiod` does not immediately break traffic — proxies keep running on their last-known configuration. What stops is *change*: no new configuration, no new certificates, no injection. That is a mesh that looks healthy right up until it is not.

## Webhooks, CRDs and gateways

The remaining objects:

- **A mutating webhook configuration** (`istio-sidecar-injector`). Cluster-scoped. It tells the API server to call `istiod` before storing certain pods.
- **A validating webhook configuration** (`istio-validator-istio-system`). Also cluster-scoped. It rejects malformed Istio configuration at apply time, so a typo in a `VirtualService` fails immediately rather than being stored and silently ignored.
- **CRDs** for `networking.istio.io`, `security.istio.io` and `telemetry.istio.io`. These are definitions, not workloads — they teach the API server what a `VirtualService` is. Nothing runs.
- **Gateways**, if the profile includes them. An ingress or egress gateway is an ordinary Deployment running Envoy — the *same* proxy image that gets injected as a sidecar, deployed standalone at the edge with a Service in front of it.

That last point is worth stating plainly because it removes a whole category of confusion: a gateway is not a special kind of component. It is a pod running `istio-proxy`, configured by the same control plane over the same protocol, that happens to sit at a network boundary instead of next to an application.

> [!TIP]
> **Try it — inventory what the install produced**
>
> ```sh
> istioctl install --set profile=demo -y
> kubectl -n istio-system get deploy,svc
> kubectl get crd | grep -c istio.io
> kubectl get mutatingwebhookconfigurations,validatingwebhookconfigurations | grep istio
> ```
>
> Expect something like:
>
> ```text
> NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
> deployment.apps/istio-egressgateway    1/1     1            1           62s
> deployment.apps/istio-ingressgateway   1/1     1            1           62s
> deployment.apps/istiod                 1/1     1            1           75s
>
> 15
> mutatingwebhookconfiguration.admissionregistration.k8s.io/istio-sidecar-injector       ...
> validatingwebhookconfiguration.admissionregistration.k8s.io/istio-validator-istio-system  ...
> ```
>
> Three Deployments, a double-digit number of CRDs, two webhooks — all from one command, and all of it ordinary Kubernetes. The CRD count varies by version; the shape does not.

## Confirming a gateway is just a proxy

The claim above is easy to verify, and doing it once makes the rest of Istio's architecture click: if gateways and sidecars run the same binary, then everything you learn about debugging one applies to the other.

> [!TIP]
> **Try it — the gateway's container and its ports**
>
> ```sh
> kubectl -n istio-system get pod -l app=istio-ingressgateway \
>   -o jsonpath='{.items[0].spec.containers[*].name}{"\n"}'
> kubectl -n istio-system get pod -l app=istio-ingressgateway \
>   -o jsonpath='{.items[0].spec.containers[0].image}{"\n"}'
> kubectl -n istio-system get svc istio-ingressgateway -o jsonpath='{range .spec.ports[*]}{.name}{"\t"}{.port}{"\n"}{end}'
> ```
>
> Expect something like:
>
> ```text
> istio-proxy
> docker.io/istio/proxyv2:1.30.5
> status-port     15021
> http2           80
> https           443
> tcp             31400
> ```
>
> One container, named `istio-proxy`, running the `proxyv2` image — the same image an injected sidecar runs. Port `15021` is the health-check port Istio proxies expose everywhere; `80` and `443` are the ones this gateway serves to the outside. On kind the Service's `EXTERNAL-IP` stays `<pending>` because there is no cloud load balancer, which is normal and does not stop it working through node ports.

## Which components a profile actually enables

A full `manifest generate` is precise but long. When the question is only "is this component on?", grepping the rendered object names is enough, and the `components` block of an `IstioOperator` maps one-to-one onto what you saw in the cluster: `components.pilot` is the `istiod` Deployment, `components.ingressGateways` and `components.egressGateways` are lists of gateway Deployments, and `components.cni` and `components.ztunnel` are the ambient pieces.

Knowing that mapping is what lets you answer a task like "install Istio without an egress gateway" without looking anything up: the component list you saw in `profile diff` is the field you set.

> *A profile is a starting document you can print, diff and override — and every object in `istio-system` traces back to one line in it.*

## Reference

- [Installation configuration profiles](https://istio.io/v1.30/docs/setup/additional-setup/config-profiles/) — the authoritative table of what each profile enables.
- [Istio architecture](https://istio.io/v1.30/docs/ops/deployment/architecture/) — how `istiod`'s three jobs relate to the data plane.
- [Gateways](https://istio.io/v1.30/docs/tasks/traffic-management/ingress/) — what the gateway Deployment does once a `Gateway` resource points at it.
- `istioctl manifest generate --help` — including `-f`, which renders your own file the same way.
