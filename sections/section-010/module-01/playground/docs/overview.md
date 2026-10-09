# Overview: Install Istio With istioctl (Playground)

This is a **playground**, not a lab. The environment starts clean, runs `bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, run `astrona destroy`, and start over.

## What is in the box

- A single-node `kind` Kubernetes cluster. `kubectl` already points at it. The context is `kind-astro-ats-013-playground-010-01`.
- **`istioctl` 1.30.5** on your PATH: `/usr/local/bin/istioctl`, or `~/.local/bin/istioctl` if the first place was not writable. Confirm it with `istioctl version --remote=false`.
- **No Istio in the cluster.** There is no `istio-system` namespace, no `networking.istio.io` CRDs (Custom Resource Definitions) and no injection webhook. Installing the control plane is the point of the module, so nothing is installed for you.

## Things to try

- Run `istioctl install --set profile=demo -y`, then `istioctl install --set profile=minimal -y` on top of it, and list which Deployments disappeared. The second run makes the cluster match the second document. That removal surprises people in production.
- Run `istioctl manifest generate --set profile=demo` and read the objects instead of applying them. Count how many objects a "single command" install really creates.
- Label `default` with `istio-injection=enabled` *after* you have created a pod there, and see that the existing pod is not touched.
- Compare `istioctl manifest generate --set profile=demo` with the same command for `minimal`, and find the exact objects that differ.
- Uninstall with `istioctl uninstall -y` (no `--purge`), then run `kubectl api-resources --api-group=networking.istio.io`. Decide for yourself whether the cluster is really clean.

## When you are done

```sh
astrona destroy ats-013-playground-010-01
```

`astrona destroy` takes the environment name, not the folder path.
