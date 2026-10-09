# Overview: In-Place Upgrade Of The Control Plane (Playground)

This is a **playground**, not a lab. The environment starts clean, runs `bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, run `astrona destroy`, and start over.

## What is in the box

- A single-node `kind` Kubernetes cluster. `kubectl` already points at it. The context is `kind-astro-ats-013-playground-030-03`.
- **Two `istioctl` binaries.** `istioctl` is **1.29.8**, the version that is installed. `istioctl-1.30.5` is **1.30.5**, the upgrade target.
- **Istio 1.29.8, installed with the `default` profile** as the only control plane (`istiod`), the default revision. The profile includes the ingress gateway `istio-ingressgateway` in `istio-system`.
- **The namespace `inplace-demo`** with `notification-service-v1` at **two replicas**, a `notification-service` Service and a `tester` pod, all with sidecar proxies. The two replicas let you see, during a rolling restart, one pod on each version at the same time.

## Things to try

- Run `istioctl-1.30.5 x precheck` before you change anything, and read every line. Run it again after the upgrade and compare.
- Upgrade the control plane, then run `istioctl proxy-status` and `istioctl version` *before* you restart any workload. The gap between the two versions is version skew.
- Restart only one of the two Deployments in `inplace-demo`, and read the mixed `proxy-status` output.
- Send requests with `curl` from the `tester` pod to the `notification-service` Service during the whole upgrade, and see whether traffic really fails.
- Go back to 1.29.8 and count the steps. A canary rollback with a revision tag takes one `istioctl tag set` and a restart; compare the two.
- Check whether the ingress gateway restarted on its own. Gateways are workloads with proxies too.

## When you are done

```sh
astrona destroy ats-013-playground-030-03
```

`astrona destroy` takes the environment name, not the folder path.
