# Summary

Sidecar injection adds the `istio-proxy` container, the Envoy sidecar proxy, to a pod. It is a mutating admission webhook: the Kubernetes API server calls `istiod` for Pods, on `CREATE` only, before it stores the pod. The decision is made once, when the pod is created. Labelling a namespace changes nothing for pods that already run, so the pods must be created again, for example with `kubectl rollout restart deployment`. Istio sets `failurePolicy: Fail` on the webhook, so if the API server cannot reach `istiod`, it refuses new pods in injected namespaces.

The `istio-sidecar-injector` webhook configuration has two entries. `namespace.sidecar-injector.istio.io` fires when the namespace has opted in and the pod has not opted out. `object.sidecar-injector.istio.io` fires when the namespace has not opted in but the pod carries `sidecar.istio.io/inject: "true"`. Its `namespaceSelector` is checked against the namespace object and its `objectSelector` against the pod.

The pod label beats the namespace label in both directions: `"false"` pulls a workload out of an injected namespace, and `"true"` pushes one into a namespace without injection. The label must sit on `spec.template.metadata.labels`. On the Deployment's own `metadata.labels` it applies cleanly and does nothing, because the webhook only sees the pod. A change to the pod template starts a rollout by itself; a change to a namespace label does not. On one namespace, `istio-injection` beats `istio.io/rev` without any warning, and the pod form of `istio.io/rev` pins one workload to a revision of the control plane.

Injection adds the `istio-proxy` container, the `istio-init` init container, volumes, environment variables and annotations. `istio-init` writes `iptables` rules that send outbound traffic to port `15001` and inbound traffic to port `15006`, and it leaves out the traffic of Envoy's own user ID `1337`. `istioctl kube-inject -f` shows the injected manifest without applying it, using the live cluster's settings. The `traffic.sidecar.istio.io/*` annotations exclude ports or address ranges from capture, and that traffic gets no mTLS, no authorization policy and no telemetry. With the Istio CNI plugin, the node writes the rules, and `istio-init` is replaced by `istio-validation` or left out.

Key facts to remember:

- Label values are strings, so `"true"` and `"false"` need quotes.
- Put the namespace label on for the default, and a pod template label on for each exception.
- Container count shows what the pod spec says; `istioctl proxy-status` shows which proxies `istiod` actually serves.
- To keep one port out of the mesh, exclude that port; do not turn off injection for the whole workload.

<!-- astrona:playground:destroy -->
