# Overview: Upgrade And Reconfigure Istio With Helm (Playground)

This is a **playground**, not a lab. The environment starts, runs `bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, run `astrona destroy`, and start over.

## What is in the box

- A single-node `kind` Kubernetes cluster. `kubectl` already points at it. The context is `kind-astro-ats-013-playground-030-01`.
- **`helm` 3** and **`istioctl` 1.29.8** on your PATH, with the `istio` chart repository added.
- **Istio 1.29.8 installed through Helm** as three releases: `istio-base` and `istiod` in `istio-system`, and `istio-ingressgateway` in `istio-ingress`. Each is at revision 1.
- `istiod` was installed with a **values file that is not the default**: access logging on, autoscaling off, and fixed CPU and memory requests. Those values live in the release, not on your disk. That is exactly the situation that makes `helm upgrade` dangerous.
- One workload with a sidecar proxy, `notification-service`, in the `default` namespace.

## Things to try

- Run `helm upgrade istiod istio/istiod -n istio-system --version 1.30.5 --set pilot.resources.requests.cpu=200m`, with no `-f`, then read `kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}'`. The upgrade reports success. Find the settings it dropped. Then compare: an upgrade with no values at all keeps them.
- Recover the lost values from `helm get values istiod -n istio-system --revision 1` and do the upgrade again, properly.
- Try `--reuse-values` together with a `-f` file that *removes* a key, and see whether the key is really gone.
- Upgrade `istiod` without touching `istio-base` and see whether anything complains. Then think about when that would hurt.
- After an upgrade, run `istioctl proxy-status` before you restart anything, and find the version mismatch.
- Use `helm history istiod -n istio-system` and `helm rollback` to go back, then check whether the application pods moved with it.

## When you are done

```sh
astrona destroy ats-013-playground-030-01
```

`astrona destroy` takes the environment name, not the folder path.
