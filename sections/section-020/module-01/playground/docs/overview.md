# Overview: Customize An Istio Installation (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-013-playground-020-01`.
- **`istioctl` 1.30.5** on your PATH.
- **Istio 1.30.5 installed with the stock `demo` profile** — `istiod`, an
  ingress gateway and an egress gateway in `istio-system`, with no overrides of
  any kind. This is your baseline: every difference you can later see is one
  you caused.

## Things to try

- Write an `IstioOperator` file that disables the egress gateway, apply it, and
  then apply a second file that forgets to mention the egress gateway at all.
  Watch what happens to the setting you never touched.
- Diff `istioctl manifest generate --set profile=default` against the same
  command for `demo`, then diff `--set profile=demo` against
  `-f <your file>`. The second diff is the honest answer to "what did I
  actually change?"
- Set `meshConfig.outboundTrafficPolicy.mode` to `REGISTRY_ONLY`, then try to
  `curl` a public address from an injected pod. The failure is the setting
  working, not the mesh breaking.
- Put a deliberate indentation error under `spec.components` and see whether
  `istioctl install` complains, and whether `istioctl manifest generate -f`
  does.
- Change a `spec.values` key and a `spec.components` key that affect the same
  thing, and work out which one wins.

## When you're done

```sh
astrona destroy ats-013-playground-020-01
```

(`astrona destroy` takes the environment name, not the config path.)
