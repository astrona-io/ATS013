# Overview: Control Sidecar Injection (Playground)

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster: your training solar system.
  `kubectl` is already pointed at it; the context is
  `kind-astro-ats-013-playground-020-02`.
- **`istioctl` 1.30.5** on your path, and **Istio 1.30.5** installed with the
  `default` profile.
- The namespace (planet) **`inject-demo`, with no injection label**. It holds
  three Deployments: `notification-service` (an nginx web server), and
  `logging-agent` and `batch-job` (both busybox containers that only sleep).
  Every pod has exactly one container.

## Things to try

- Label the namespace, then check the pods *without* restarting anything.
  Nothing changes. Then `rollout restart` one Deployment and compare.
- Put `sidecar.istio.io/inject: "false"` on the Deployment's own
  `metadata.labels` instead of on `spec.template.metadata.labels`, restart, and
  confirm it did nothing. Then move it to the right place.
- Force `batch-job` in with `sidecar.istio.io/inject: "true"`, then remove the
  namespace label and restart. Work out why it still gets a sidecar.
- Look at an injected pod's spec and read what injection added: the
  `istio-proxy` container, the init container, and the environment variables
  they carry.
- Run `istioctl kube-inject -f` on a plain Deployment manifest and compare the
  output with the original.

## When you're done

```sh
astrona destroy ats-013-playground-020-02
```

`astrona destroy` takes the environment name, not the folder path.
