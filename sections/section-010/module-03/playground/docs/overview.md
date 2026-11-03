# Overview: Inspect Profiles And Verify An Installation (Playground)

This is a **playground**, not a lab. The environment starts clean, runs `bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit` and no pass or fail. Status: UNTESTED.

## What is in the box

- A single-node `kind` Kubernetes cluster. `kubectl` already points at it.
- **`istioctl` 1.30.5** on your PATH.
- **Istio 1.30.5 installed with the `default` profile**: `istiod` and the `istio-ingressgateway` in `istio-system`.
- The namespace **`check-demo`** with `notification-service` (nginx) and a `tester` pod. The namespace carries `istio-injection=enabled`, but the pods were created before the label, so they have no sidecar. A `VirtualService` named `notification-route` points at the host `notification-svc`, which does not exist.

## Things to try

- Run `istioctl profile list`, then `istioctl profile dump default` and `istioctl profile diff default demo`.
- Generate the manifest of a profile with `istioctl manifest generate --set profile=demo` and count the objects with `grep -c '^kind:'`.
- Run `istioctl verify-install`, then `istioctl analyze -n check-demo`, and read each code.
- Run `istioctl analyze --all-namespaces` and see what it says about the other namespaces.
- Fix the route and the missing sidecars, and run the analysis again.
- Run `istioctl proxy-status` before and after the restart of the pods.

## When you are done

```sh
astrona destroy ats-013-playground-010-03
```
