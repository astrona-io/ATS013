# Upgrade And Reconfigure Istio With Helm

Helm is a package manager for Kubernetes: it installs a chart (a package of templated Kubernetes objects) as a named release, and it can upgrade or roll back that release later. This module shows how to upgrade an Istio installation that Helm manages, and how to keep every setting it had while you do it.

`helm upgrade` has one default that surprises people. The command builds the new release from the chart plus **the values you pass on this run**. It does not reuse the values from the last run. Any setting you passed at install time and do not pass again is gone, and Helm still reports success.

So this module covers where the old settings really live, what the value flags really do, and why an upgrade needs one more step after the control plane is new. It ends with what `helm rollback` restores and what it leaves alone.

## Learning objectives

After this module you can:

- Say where Helm stores a release's manifests and values, and read an older revision's values back out of the cluster.
- Explain how `helm upgrade` computes values, and predict what `--reuse-values` and `--reset-values` do.
- Recover settings that exist only inside a release, and rebuild a values file from them.
- Upgrade `base`, `istiod` and a gateway to a new version in the right order without losing mesh settings.
- Spot version skew between the control plane and the data plane with `istioctl version` and `istioctl proxy-status`, and finish the upgrade.
- Roll a release back to an earlier revision, and say what the rollback leaves untouched.

## Before you start

This module expects some Kubernetes knowledge and an Istio installation made with Helm.

### What you should already know

- **Kubernetes basics.** Namespaces, Deployments, Secrets, ConfigMaps, and `kubectl rollout restart`.
- **Installing Istio with Helm.** Istio comes as three Helm charts: `istio/base` (the CRDs, or Custom Resource Definitions, which add Istio's object kinds to the Kubernetes API), `istio/istiod` (the control plane) and `istio/gateway` (an ingress or egress gateway). You install them in that order, and `helm get values` shows the values a release was given.
- **What `meshConfig` is.** It holds the mesh-wide settings, such as access logging and the outbound traffic policy. `istiod` stores them in the `istio` ConfigMap in `istio-system`.

### What is in your playground

The playground is one single-node `kind` cluster with **`helm` 3** and **`istioctl` 1.29.8** ready to use, and the `istio` chart repository already added.

**Istio 1.29.8 is installed as three Helm releases**, each at revision 1:

| Release | Namespace | Chart |
| --- | --- | --- |
| `istio-base` | `istio-system` | `istio/base` |
| `istiod` | `istio-system` | `istio/istiod` |
| `istio-ingressgateway` | `istio-ingress` | `istio/gateway` |

One workload with a sidecar proxy, `notification-service`, runs in the `default` namespace.

One detail is on purpose and matters for the whole module. `istiod` was installed with a **values file that is no longer on disk**. Access logging is on, autoscaling is off, and there are fixed resource requests. The only record of that is inside the release. You will meet this situation far more often than a clean one.

Start your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Read the parts in this order:

1. **Where A Release Lives:** the Secret behind every release, revision numbers, and the read commands that tell you what a cluster runs and how it was configured.
2. **How `helm upgrade` Computes Values:** the default value handling, `--reuse-values` and `--reset-values`, a setting lost on purpose, and getting a values file back from an older revision.
3. **Upgrading In Order And Finishing The Job:** the chart order, version skew, and the data plane restart that really completes the upgrade. The graded lab "Upgrade And Reconfigure Istio With Helm" follows this part.
4. **Rolling Back And A Safe Procedure:** what `helm rollback` restores and what it does not, and a step-by-step upgrade procedure. The graded lab "Roll Back A Helm Release Of istiod" follows this part.

A summary closes the module.
