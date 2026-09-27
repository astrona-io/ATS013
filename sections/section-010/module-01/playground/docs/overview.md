# Overview: Install Istio With istioctl (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-013-playground-010-01`.
- **`istioctl` 1.30.5** on your PATH (`/usr/local/bin/istioctl`, or
  `~/.local/bin/istioctl` if the first was not writable). Confirm with
  `istioctl version --remote=false`.
- **No Istio in the cluster.** No `istio-system` namespace, no
  `networking.istio.io` CRDs, no injection webhook. Installing the control
  plane is the point of the module, so nothing is pre-installed.

## Things to try

- Run `istioctl install --set profile=demo -y`, then `istioctl install --set
  profile=minimal -y` on top of it, and list which Deployments disappeared.
  The second run reconciles the cluster to the second file — that removal is
  the behaviour people are surprised by in production.
- Run `istioctl manifest generate --set profile=demo` and read the manifest
  instead of applying it. Count how many objects a "single command" install
  really creates.
- Label `default` with `istio-injection=enabled` *after* you have already
  created a pod there, and see that the existing pod is untouched.
- Diff `istioctl manifest generate --set profile=demo` against the same command
  for `minimal` and find the exact objects that differ.
- Uninstall with `istioctl uninstall -y` (no `--purge`) and then check
  `kubectl api-resources --api-group=networking.istio.io`. Decide for yourself
  whether the cluster is really clean.

## When you're done

```sh
astrona destroy ats-013-playground-010-01
```

(`astrona destroy` takes the environment name, not the config path.)
