# Overview: Customize Gateways And Control Plane Resources (Playground)

This is a **playground**, not a lab. The environment starts clean, runs `bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit` and no pass or fail. Status: UNTESTED.

## What is in the box

- A single-node `kind` Kubernetes cluster. `kubectl` already points at it.
- **`istioctl` 1.30.5** on your PATH.
- **Istio 1.30.5 installed with the `default` profile**: `istiod` and the `istio-ingressgateway` in `istio-system`. The gateway Service has type `LoadBalancer`, and its external address stays `<pending>` because `kind` has no load balancer.
- The namespace **`gw-demo`** with `notification-service` (nginx), a `tester` pod, a `Gateway` named `edge-gateway` and a `VirtualService` named `notification-edge` that publish the service on port `80`.

## Things to try

- Run `istioctl profile dump default --config-path components` and find the gateway settings.
- Change the gateway Service to `NodePort` with an `IstioOperator` file, and request the service through the node port from the `tester` pod.
- Set the `HorizontalPodAutoscaler` bounds with `hpaSpec`, and read the result with `kubectl -n istio-system get hpa`.
- Set `replicaCount`, a `nodeSelector` or resource requests on `istiod` under `components.pilot.k8s`.
- Render the change first with `istioctl manifest generate -f <file>` and compare it with the live objects using `kubectl diff -f -`.
- Disable the gateway with `enabled: false`, install, and see what the install removes.

## When you are done

```sh
astrona destroy ats-013-playground-020-03
```
