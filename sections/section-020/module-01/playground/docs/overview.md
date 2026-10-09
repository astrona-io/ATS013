# Overview: Customize An Istio Installation (Playground)

This is a **playground**, not a lab. The environment starts clean, runs `bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, run `astrona destroy`, and start over.

## What is in the box

- A single-node `kind` Kubernetes cluster. `kubectl` already points at it. The context is `kind-astro-ats-013-playground-020-01`.
- **`istioctl` 1.30.5** on your PATH.
- **Istio 1.30.5 installed with the built-in `demo` profile**: `istiod` (Istio's control plane), an ingress gateway and an egress gateway in `istio-system`, with no changes of any kind. This is your starting point: every difference you see later is one you caused.

## Things to try

- Write an `IstioOperator` file (the YAML document you pass to `istioctl install -f`) that turns off the egress gateway, and apply it. Then apply a second file that does not mention the egress gateway at all. Watch what happens to the setting you never touched.
- Compare `istioctl manifest generate --set profile=default` with the same command for `demo`. Then compare `--set profile=demo` with `-f <your file>`. The second comparison is the honest answer to "what did I actually change?"
- Set `meshConfig.outboundTrafficPolicy.mode` to `REGISTRY_ONLY`, then try to `curl` a public address from a pod with a sidecar proxy. The failure is the setting working, not the mesh breaking.
- Put a deliberate indentation error under `spec.components`, and see whether `istioctl install` complains and whether `istioctl manifest generate -f` shows your change.
- Change a `spec.values` key and a `spec.components` key that affect the same thing, and work out which one wins.

## When you are done

```sh
astrona destroy ats-013-playground-020-01
```

`astrona destroy` takes the environment name, not the folder path.
