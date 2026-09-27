# Overview: Control Sidecar Injection (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-013-playground-020-02`.
- **`istioctl` 1.30.5** on your PATH, and **Istio 1.30.5** installed with the
  `default` profile.
- Namespace **`inject-demo` with no injection label**, holding three
  Deployments: `notification-service` (an nginx web server), `logging-agent`
  and `batch-job` (both busybox sleepers). Every pod currently has exactly one
  container.

## Things to try

- Label the namespace, then check the pods *without* restarting anything.
  Nothing changes. Then `rollout restart` one Deployment and compare.
- Put `sidecar.istio.io/inject: "false"` on the Deployment's own
  `metadata.labels` instead of on `spec.template.metadata.labels`, restart, and
  confirm it did nothing. Then move it to the right place.
- Force `batch-job` in with `sidecar.istio.io/inject: "true"`, then remove the
  namespace label entirely and restart. Work out why it is still injected.
- Dump an injected pod's spec and read what the sidecar actually added: the
  `istio-proxy` container, the init container, and the environment variables
  they carry.
- Run `istioctl kube-inject -f` on a plain Deployment manifest and diff the
  output against the original.

## When you're done

```sh
astrona destroy ats-013-playground-020-02
```

(`astrona destroy` takes the environment name, not the config path.)
