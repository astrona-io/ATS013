# Overview: Customize An Istio Installation (Playground)

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster: your training solar system.
  `kubectl` is already pointed at it; the context is
  `kind-astro-ats-013-playground-020-01`.
- **`istioctl` 1.30.5** on your path.
- **Istio 1.30.5 installed with the stock `demo` profile**: `istiod`, an
  ingress gateway and an egress gateway in `istio-system`, with no changes of
  any kind. This is your starting point: every difference you see later is
  one you caused.

## Things to try

- Write an `IstioOperator` file that turns off the egress gateway, apply it,
  and then apply a second file that does not mention the egress gateway at
  all. Watch what happens to the setting you never touched.
- Compare `istioctl manifest generate --set profile=default` with the same
  command for `demo`. Then compare `--set profile=demo` with
  `-f <your file>`. The second comparison is the honest answer to "what did I
  actually change?"
- Set `meshConfig.outboundTrafficPolicy.mode` to `REGISTRY_ONLY`, then try to
  `curl` a public address from an injected pod. The failure is the setting
  working, not the mesh breaking.
- Put a deliberate indentation error under `spec.components` and see whether
  `istioctl install` complains, and whether `istioctl manifest generate -f`
  shows your change.
- Change a `spec.values` key and a `spec.components` key that affect the same
  thing, and work out which one wins.

## When you're done

```sh
astrona destroy ats-013-playground-020-01
```

`astrona destroy` takes the environment name, not the folder path.
