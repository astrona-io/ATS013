# Overview: Upgrade And Reconfigure Istio With Helm (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-013-playground-030-01`.
- **`helm` 3** and **`istioctl` 1.29.8** on your PATH, with the `istio` chart
  repository added.
- **Istio 1.29.8 installed through Helm** as three releases: `istio-base` and
  `istiod` in `istio-system`, `istio-ingressgateway` in `istio-ingress`. Each
  is at revision 1.
- `istiod` was installed with a **non-default values file** — access logging
  on, autoscaling off, explicit CPU/memory requests. Those values live in the
  release, not on your disk, which is exactly the situation that makes
  `helm upgrade` dangerous.
- One injected workload, `notification-service`, in the `default` namespace.

## Things to try

- Run `helm upgrade istiod istio/istiod -n istio-system --version 1.30.5` with
  no `-f` and no `--reuse-values`, then read
  `kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}'`. The
  upgrade reports success. Find what it silently dropped.
- Recover the lost values from `helm get values istiod -n istio-system
  --revision 1` and redo the upgrade properly.
- Try `--reuse-values` together with a `-f` file that *removes* a key, and see
  whether the key is actually gone.
- Upgrade `istiod` without touching `istio-base` and see whether anything
  complains. Then think about when that would bite.
- After an upgrade, run `istioctl proxy-status` before restarting anything, and
  find the version mismatch.
- Use `helm history istiod -n istio-system` and `helm rollback` to get back,
  then check whether the application pods moved with it.

## When you're done

```sh
astrona destroy ats-013-playground-030-01
```

(`astrona destroy` takes the environment name, not the config path.)
