# Overview: Mix Sidecar And Ambient Mode And Migrate A Namespace (Playground)

This is a **playground**, not a lab. The environment starts clean, runs `bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit` and no pass or fail. Status: UNTESTED.

## What is in the box

- A single-node `kind` Kubernetes cluster. `kubectl` already points at it.
- **`istioctl` 1.30.5** on your PATH.
- **Istio 1.30.5 installed with the `ambient` profile**: `istiod` plus the `istio-cni-node` and `ztunnel` DaemonSets. The same `istiod` still injects sidecars into namespaces that ask for them.
- The namespace **`legacy-shop`** with the label `istio-injection=enabled`. Its pods (`notification-service` and `tester`) each have an `istio-proxy` sidecar.
- The namespace **`new-shop`** with the label `istio.io/dataplane-mode=ambient`. Its pods have one container each.

## Things to try

- Compare `kubectl get pods` in both namespaces, then run `istioctl ztunnel-config workload` and `istioctl proxy-status`.
- Send a request from the `tester` pod in `legacy-shop` to the service in `new-shop`, and the other way round.
- Move `legacy-shop` to ambient mode: swap the labels, check the pods, then restart the Deployments and check again.
- Put both labels on a namespace and read which one wins for new pods.
- Move a namespace back to sidecar mode.

## When you are done

```sh
astrona destroy ats-013-playground-040-03
```
