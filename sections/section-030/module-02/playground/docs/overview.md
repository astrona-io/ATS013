# Overview: Canary Upgrade With Revisions And Revision Tags (Playground)

This is a **playground**, not a lab. The environment starts clean, runs `bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, run `astrona destroy`, and start over.

## What is in the box

- A single-node `kind` Kubernetes cluster. `kubectl` already points at it. The context is `kind-astro-ats-013-playground-030-02`.
- **Two `istioctl` binaries**, so an upgrade only happens when you choose it:
  - `istioctl` is **1.29.8**, the version that is installed;
  - `istioctl-1.30.5` is **1.30.5**, the upgrade target.
- **Istio 1.29.8, installed with the `demo` profile as the default control plane with no revision name.** There is exactly one `istiod` Deployment (the Istio control plane) and one injection webhook, the mutating admission webhook that adds the sidecar proxy to new pods.
- The namespace **`canary-demo`**, labelled `istio-injection=enabled`, running one `notification-service-v1` pod with a sidecar proxy.

## Things to try

- Install the 1.30.5 revision, then run `kubectl -n canary-demo get pods` straight away. Nothing moved. Work out what the install really changed.
- Set `istio-injection=enabled` and `istio.io/rev=1-30-5` on the namespace at the same time, restart the Deployment, and see which control plane wins.
- Watch `istioctl proxy-status` while a `rollout restart` is halfway done, so you see both control planes serving proxies at once.
- Create a `prod` revision tag, point it at the old revision, move it to the new one, and move it back. Count how many commands a rollback took, compared with relabelling the namespace.
- Run `istioctl uninstall --revision default` *before* restarting the workloads, then check whether the running pods still have a control plane.

## When you are done

```sh
astrona destroy ats-013-playground-030-02
```

`astrona destroy` takes the environment name, not the folder path.
