# Overview: Install Istio With Helm (Playground)

> Declared in [`../config.yaml`](../config.yaml) under `metadata.docs.guide`.

This is a **playground**, not a lab. The environment starts clean, runs
`bootstrap/prepare.sh`, and then waits. There is no task, no `astrona submit`,
and no pass/fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it —
  the context is `kind-astro-ats-013-playground-010-02`.
- **`helm` 3** and **`istioctl` 1.30.5** on your PATH. `istioctl` is here only
  so you can verify what the charts did; the module installs with Helm.
- The **`istio` chart repository** already added and updated, so
  `helm search repo istio` works immediately.
- **No chart installed.** `helm ls -A` is empty and the cluster has no Istio
  CRDs.

## Things to try

- Install `istio/istiod` *first*, before `istio/base`, and read the failure
  carefully. The error names the missing CRD — that is the whole reason the
  chart order is fixed.
- Run `helm show values istio/istiod | less` and find where `meshConfig`,
  `pilot` and `global` sit in the tree. Compare those key paths with
  `spec.values` in an `IstioOperator`.
- Install a gateway release twice under two different names in two namespaces,
  and check what the Deployment and Service end up being called.
- Run `helm uninstall istio-base -n istio-system`, then
  `kubectl get crd | grep istio.io`. Decide whether the uninstall was complete.
- Install the gateway with `--set service.type=NodePort` and see which Service
  fields the chart changed.

## When you're done

```sh
astrona destroy ats-013-playground-010-02
```

(`astrona destroy` takes the environment name, not the config path.)
