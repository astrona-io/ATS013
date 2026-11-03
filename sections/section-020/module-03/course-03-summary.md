# Summary

Every object that an Istio install creates can be shaped through the `IstioOperator` file. The settings sit under `spec.components`, which lists `base`, `pilot`, `ingressGateways`, `egressGateways`, `cni` and `ztunnel`. Each component has an `enabled` flag, and a component that a profile turns on is removed by the next install when you set it to `false`. The gateway lists use the `name` field to pick the entry, so an overlay that names an existing gateway changes it.

Under each component the `k8s` block overrides the Kubernetes objects. Its main fields are `resources`, `replicaCount`, `hpaSpec`, `nodeSelector`, `affinity`, `tolerations`, `service`, `env`, `podAnnotations` and `overlays`. The path in the file follows the structure of the live object, so a value under `components.pilot.k8s.resources.requests` appears in the `istiod` Deployment. Changes belong in the file, because the next install renders the objects again and overwrites any hand edit.

The ingress gateway Service has the type `LoadBalancer` in the `default` profile. A `kind` cluster has no load balancer, so the external address stays pending. Setting `service.type` to `NodePort` with a fixed `nodePort` makes the gateway reachable on the node. The Service port `80` forwards to the container port `8080`, and the overlay lists every port so the file shows the whole Service.

`hpaSpec` sets the minimum and maximum replicas of the `HorizontalPodAutoscaler`, and scaling by load needs a metrics source in the cluster. `replicaCount` sets a fixed number and must not be combined with `hpaSpec`. `resources.requests` sets what the container asks the scheduler for.

Key facts to remember:

- Settings live in `spec.components.<name>.k8s`, never in the live objects.
- `istioctl manifest generate -f <file>` shows the result before anything is applied.
- A gateway entry is selected by its `name`.
- `kind` needs `NodePort`, because it has no load balancer.

<!-- astrona:playground:destroy -->
