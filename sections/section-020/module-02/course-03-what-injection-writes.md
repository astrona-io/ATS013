# What Injection Writes Into The Pod

"The sidecar intercepts traffic" is easy to say and hard to debug. When a workload behaves strangely after it joins the mesh, you need to know what injection put into the pod spec: which containers appear, how traffic reaches the proxy without the application knowing, and which ports do what. This part turns that sentence into things you can read in a manifest and check on a running pod.

## The patch, in summary

When the API server calls `istiod` for a new pod, `istiod` answers with a JSON patch that the API server applies before it stores the pod. With the `default` profile, the patch adds these parts:

- **`istio-proxy`**: the Envoy sidecar proxy. It gets its configuration from `istiod` and holds the workload's certificate for mTLS (mutual TLS, where both sides of a connection present a certificate).
- **`istio-init`**: an init container, which is a container that runs to the end before the application containers start. It runs `istio-iptables` to install the traffic rules, and it needs the `NET_ADMIN` and `NET_RAW` Linux capabilities to do so.
- **Volumes**, including `istio-envoy` (the proxy's runtime configuration), `istio-data`, `istio-podinfo` and `istio-token`. `istio-token` holds a short-lived service account token. The proxy uses it to prove its identity to `istiod` when it asks for a certificate.
- **Environment variables and annotations** that describe the pod to the proxy: its service account, namespace, labels, and the `discoveryAddress` of `istiod`.

The init container is the piece that makes the whole model work, so the next section looks at it closely.

## How traffic gets redirected

`istio-init` runs once, inside the pod's network namespace, before any application container starts. All containers in a pod share that network namespace, so the `iptables` rules it writes apply to all of them. `iptables` is the Linux kernel's packet filtering and redirection tool.

The rules send traffic to two ports on localhost, where Envoy listens. **Outbound** traffic that leaves the pod goes to port **15001**. **Inbound** traffic that arrives at the pod goes to port **15006**.

```mermaid
flowchart LR
    A["App container"] -->|"connect notification-service:80"| T["iptables rules"]
    T -->|"redirect"| P["istio-proxy :15001"]
    P -->|"routing, mTLS, telemetry"| U["Upstream"]
```

The diagram shows one outbound request: the application connects as normal, the `iptables` rules written by `istio-init` send the connection to Envoy on port `15001`, and Envoy applies routing, mutual TLS and telemetry before it opens its own connection to the destination.

That is the "no application changes" claim, made concrete. The application opens a connection to `notification-service:80` exactly as it would without a mesh. The kernel redirects it. Envoy picks it up, decides where it really goes, encrypts it and sends it on. Nothing in the application's code or configuration changed, and nothing in it can tell.

The ports are fixed, and you will meet them in command output:

| Port | Role |
| --- | --- |
| `15001` | Outbound capture: where redirected outgoing traffic lands |
| `15006` | Inbound capture: where redirected incoming traffic lands |
| `15008` | HBONE (HTTP-Based Overlay Network Environment), the tunnel port used in ambient mode |
| `15020` | Merged telemetry and the proxy's own health endpoint |
| `15021` | Health checking, exposed by gateways and sidecars |
| `15090` | Envoy's raw Prometheus metrics |
| `15012` | On `istiod`'s side: the port sidecars connect to for configuration and certificates |

## Reading the change instead of trusting it

You do not have to take this list on trust. `istioctl kube-inject` makes the same change on your own machine and prints the result instead of applying it. Read the name as "Kubernetes manifest, inject": a manifest goes in, and an injected manifest comes out.

To do that, it reads the cluster's live injection settings: the `istio-sidecar-injector` ConfigMap and the mesh configuration. So its output shows what *your* control plane would do, not a generic template. It has two practical uses. It shows exactly what injection would do before it happens, and it produces manifests for a cluster where the webhook is unavailable or not used on purpose.

Save the `notification-service` Deployment to a file and run it through `kube-inject`. The second command sends the injected manifest to `kubectl create --dry-run=client`, which only parses it, and prints the names of the init containers and the containers. The third prints the start of the `initContainers` list, where the `istio-init` arguments are:

<!-- astrona:playground:renew -->

```sh
kubectl -n inject-demo get deployment notification-service -o yaml > notification-service.yaml
istioctl kube-inject -f notification-service.yaml | kubectl create --dry-run=client -f - -o jsonpath='{.spec.template.spec.initContainers[*].name} {.spec.template.spec.containers[*].name}{"\n"}'
istioctl kube-inject -f notification-service.yaml | grep -A10 'initContainers:'
```

The output looks like this:

```text
istio-init istio-proxy notification-service
      initContainers:
      - args:
        - istio-iptables
        - -p
        - "15001"
        - -z
        - "15006"
        - -u
        - "1337"
        - -m
        - REDIRECT
```

Injection adds two init containers. `istio-init` runs first, writes the traffic rules and exits. `istio-proxy` is the sidecar proxy itself. It runs as a native sidecar: an init container with `restartPolicy: Always`, so Kubernetes starts it before the application container and keeps it running beside it. In the YAML, the fields of each container are sorted by name, so `args` comes before `name: istio-init`.

`-p 15001` is the outbound capture port and `-z 15006` is the inbound one: the two numbers from the diagram, passed to the command that writes the rules. `-u 1337` is the user ID Envoy runs as. The rules leave that user's traffic out of the redirect, so the proxy's own outgoing connections do not loop back into itself.

The `istio-init` container uses the *same* `proxyv2` image as the sidecar (`registry.istio.io/release/proxyv2:1.30.5`). It is one image with several entry points.

## The exclusions you can set

The redirect rules are built from arguments, so you can change them. Annotations on the pod template change those arguments for one workload. This section lists the useful annotations and then shows one becoming a rule.

Four annotations control what the rules capture:

- `traffic.sidecar.istio.io/excludeOutboundPorts`: outgoing ports that the rules do not capture.
- `traffic.sidecar.istio.io/excludeInboundPorts`: incoming ports that the rules do not capture.
- `traffic.sidecar.istio.io/excludeOutboundIPRanges`: destination address ranges that the rules do not capture, often a database or a metadata endpoint.
- `traffic.sidecar.istio.io/includeOutboundIPRanges`: the opposite. The rules capture *only* these ranges, and everything else goes out directly.

These annotations are useful and dangerous at the same time. Traffic left out of capture gets no mTLS, no authorization policy and no telemetry. It is outside the mesh while the workload still looks like part of it. Use them only for a specific reason, such as a protocol Envoy handles badly, and write the reason next to the annotation.

Add an exclusion for port `5432` to `notification-service`, wait for the rollout, and read the new `istio-init` arguments:

```sh
kubectl -n inject-demo patch deployment notification-service -p \
  '{"spec":{"template":{"metadata":{"annotations":{"traffic.sidecar.istio.io/excludeOutboundPorts":"5432"}}}}}'
kubectl -n inject-demo rollout status deployment notification-service --timeout=120s
kubectl -n inject-demo get pod -l app=notification-service \
  -o jsonpath='{.items[0].spec.initContainers[0].args}{"\n"}' | tr ',' '\n' | grep -A1 -- '-o'
```

The output looks like this:

```text
"-o"
"5432"
```

`istiod` turned the annotation into an `-o 5432` argument to `istio-iptables`, and `istio-iptables` turns that argument into an exception in the rules. The annotation is not special: it is a value passed into a command line. The pod still has its `istio-proxy` container, so all other traffic still goes through the proxy.

Remove the exclusion again:

```sh
kubectl -n inject-demo patch deployment notification-service --type=json -p '[{"op":"remove","path":"/spec/template/metadata/annotations/traffic.sidecar.istio.io~1excludeOutboundPorts"}]'
```

## The Istio CNI plugin

Everything so far relies on `istio-init`, and some clusters do not allow it. The init container needs `NET_ADMIN` and `NET_RAW`, and Pod Security Standards can forbid those capabilities. Istio's answer is the **Istio CNI plugin**. CNI (Container Network Interface) is the Kubernetes standard for plugins that set up pod networking. The Istio CNI plugin runs as a DaemonSet and writes the same traffic rules from the node, when the pod is created, so the pod itself needs no extra rights.

With `istio-cni` installed, injection still adds the `istio-proxy` container. A much smaller `istio-validation` init container replaces `istio-init`, or the init container is left out entirely, depending on the settings. The traffic redirect is the same; only the component that writes the rules changes.

This matters for two reasons. First, if you inspect a pod on a cluster with the CNI plugin and find no `istio-init`, the pod is not broken. Second, ambient mode *requires* the CNI plugin: it is how a workload can join the mesh without any change to the pod.

## Good habits for real clusters

The mechanics above lead to a few working habits. **Use the namespace label for the default and the pod label for the exception.** A namespace-wide rule with a few documented overrides for single workloads is far easier to check than labels on every workload. Keep the overrides in the manifests, in version control, with a comment that says why.

**Restarts have a real cost.** Turning on injection across a busy namespace means replacing every pod in it. Check the `PodDisruptionBudget`s, go one Deployment at a time, and expect slightly slower pod starts afterwards.

**Use `istioctl proxy-status` as the cross-check.** Counting containers tells you what the pod spec says. `istioctl proxy-status` lists every proxy that is connected to `istiod` and receiving configuration from it. A workload in one list but not the other is a real problem, often a proxy that cannot reach `istiod` on port `15012`.

> [!TIP]
> Before you add a workload you do not know well to the mesh, run `istioctl kube-inject -f` on its manifest and read what would be added. It costs nothing, needs no restart, and shows the exact containers, ports and exclusions your control plane would apply.

You now know what injection writes into a pod: the `istio-proxy` container, the `istio-init` container that redirects traffic to ports `15001` and `15006`, and the volumes and settings the proxy needs. You can read that change in advance with `istioctl kube-inject` and narrow it with a `traffic.sidecar.istio.io` annotation. The open question for real work is when an exclusion is justified, because every excluded port is traffic the mesh no longer sees.

## Common pitfalls

> [!WARNING]
> **Assuming a missing `istio-init` means injection failed.** On a cluster with the Istio CNI plugin it is expected. Look for the `istio-proxy` container instead.
>
> **Excluding ports or address ranges without writing down why.** Excluded traffic silently leaves the mesh: no mTLS, no authorization, no telemetry, while the workload still looks like part of the mesh.
>
> **Turning off injection to fix one port.** `sidecar.istio.io/inject: "false"` takes every port out of the mesh. An exclusion annotation takes out only the port you name.
>
> **Adding a start-up delay that is no longer needed.** An application that connects the moment it starts used to race the proxy. With native sidecars, Kubernetes starts `istio-proxy` first and waits for its startup probe (`/healthz/ready` on port `15021`) before it starts the application container. Only on a cluster without native sidecars do you need `meshConfig.defaultConfig.holdApplicationUntilProxyStarts: true` for the same order.
>
> **Expecting `istioctl kube-inject` output to work everywhere.** It renders against the live cluster's settings, so output from one cluster is not portable to another one that runs a different version.
>
> **Forgetting that gateways are not injected.** An ingress or egress gateway is a standalone Envoy Deployment from the profile or the gateway chart. Injection labels on its namespace do not apply to it.

## Your mission: Exclude A Port From Sidecar Traffic Capture Lab

You can now read what injection adds to a pod and change the traffic rules for one workload with an annotation. The lab asks you to take one outbound port of a workload out of traffic capture while the workload stays in the mesh, with the setting on the object that injection reads.

The lab runs on its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-013-playground-020-02
```

Then start the lab. The task is on the next page; solve it on your own first:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-020/module-02/labs/lab-02
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-02/labs/lab-02
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-013-lab-020-02-02
astrona start ats-013-playground-020-02
```
