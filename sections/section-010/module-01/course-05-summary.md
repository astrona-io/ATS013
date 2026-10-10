# Summary

`istioctl install` is a render-and-apply tool. It loads a profile, merges your `-f` files and then your `--set` flags on top, renders plain Kubernetes objects on your machine, and only then applies them to the cluster and waits for them to be ready. No operator runs in the cluster afterwards, so nothing records what you typed, and a hand edit of an installed object lasts only until the next install. `istioctl manifest generate` prints the rendered objects without applying them, and `istioctl x precheck` checks whether the cluster can accept Istio, not whether your YAML is right.

A profile is a complete `IstioOperator` document, not a switch. `default` installs `istiod` and an ingress gateway, `demo` adds an egress gateway, `minimal` installs `istiod` only, and `ambient` adds `istio-cni` and `ztunnel`. The install creates the `istiod` Deployment, which is the xDS server, the certificate authority and the injection webhook backend in one process. It also creates the `istio-sidecar-injector` mutating webhook, a validating webhook, the Istio CRDs and, depending on the profile, gateways that run the same `istio-proxy` image as a sidecar.

Sidecar injection happens once, inside the Kubernetes API server, when a pod is created. The API server calls the webhook only for pods in a namespace whose labels match its selector, such as `istio-injection=enabled`. Pods that existed before the label keep one container until they are created again, for example with `kubectl rollout restart deployment`. Once proxies exist, the client, the control plane and the data plane each have a version, and Istio supports a gap of one minor version between them. `istioctl version` shows all three, and `istioctl proxy-status` shows which `istiod` each proxy is connected to and whether it accepted the latest configuration.

A second `istioctl install` makes the cluster match the new document. It prunes objects that carry its ownership labels for that revision and are no longer in the render, and it resets fields the new document leaves out. Objects you created by hand and objects of other revisions are never pruned. `istioctl uninstall --revision <name>` removes one control plane; `--purge` removes every revision and the CRDs. Neither removes the `istio-system` namespace, namespace injection labels or the sidecars of running pods.

Key facts to remember:

- `--set` always beats `-f`, wherever it sits on the command line.
- `istioctl manifest generate` replaced the removed `istioctl profile` commands.
- `NOT SENT` in `proxy-status` means there is nothing of that type to send, not a fault.
- Keep the installation in a committed file and pass it with `-f` on every run.

<!-- astrona:playground:destroy -->
