# Overview: Canary Upgrade With Revisions And Revision Tags (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-013-playground-030-02`.
- **Two istioctl binaries**, so an upgrade has to be deliberate:
  - `istioctl` → **1.29.8**, the version that is installed
  - `istioctl-1.30.5` → **1.30.5**, the upgrade target
- **Istio 1.29.8 installed with the `demo` profile as the default,
  unrevisioned control plane.** There is exactly one `istiod` Deployment and
  one injection webhook.
- Namespace **`canary-demo`** labelled `istio-injection=enabled`, running one
  injected `notification-service` pod.

## Things to try

- Install the 1.30.5 revision, then immediately check
  `kubectl -n canary-demo get pods`. Nothing moved. Work out what the install
  actually changed.
- Set `istio-injection=enabled` and `istio.io/rev=1-26-1` on the namespace at
  the same time, restart, and see which control plane wins.
- Watch `istioctl proxy-status` while a `rollout restart` is halfway done, so
  you see both control planes serving at once.
- Create a `prod` tag, point it at the old revision, move it to the new one,
  and move it back. Count how many commands a rollback took compared with
  relabelling the namespace.
- Try `istioctl uninstall --revision default` *before* restarting the
  workloads, then check whether the running pods still have a control plane.

## When you're done

```sh
astrona destroy ats-013-playground-030-02
```

(`astrona destroy` takes the environment name, not the config path.)
