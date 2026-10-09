# Overview: Canary Upgrade With Revisions And Revision Tags (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What is in the box

- A single-node `kind` Kubernetes cluster: your training solar system.
  `kubectl` already points at it. The context is
  `kind-astro-ats-013-playground-030-02`.
- **Two `istioctl` binaries**, so an upgrade has to be on purpose:
  - `istioctl` is **1.29.8**, the version that is installed;
  - `istioctl-1.30.5` is **1.30.5**, the upgrade target.
- **Istio 1.29.8, installed with the `demo` profile as the default control
  plane with no revision name.** There is exactly one `istiod` Deployment and
  one injection webhook.
- The namespace **`canary-demo`**, labelled `istio-injection=enabled`, running
  one `notification-service` pod with a sidecar.

## Things to try

- Install the 1.30.5 revision, then check
  `kubectl -n canary-demo get pods` straight away. Nothing moved. Work out
  what the install really changed.
- Set `istio-injection=enabled` and `istio.io/rev=1-30-5` on the namespace at
  the same time, restart, and see which control plane wins.
- Watch `istioctl proxy-status` while a `rollout restart` is halfway done, so
  you see both control planes serving at once.
- Create a `prod` tag, point it at the old revision, move it to the new one,
  and move it back. Count how many commands a rollback took, compared with
  relabelling the namespace.
- Try `istioctl uninstall --revision default` *before* restarting the
  workloads, then check whether the running pods still have a control plane.

## When you are done

```sh
astrona destroy ats-013-playground-030-02
```

`astrona destroy` takes the environment name, not the folder path.
