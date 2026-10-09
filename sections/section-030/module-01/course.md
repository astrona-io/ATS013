# Upgrade And Reconfigure Istio With Helm

Astronaut, this module is about rebuilding mission control from a newer kit without losing the notes you wrote on the old order form. In Helm terms: upgrading an Istio installation that Helm manages, and keeping every setting it had.

`helm upgrade` has one default that surprises people exactly once. The command builds the new release from the chart plus **the values you pass on this run**. It does not reuse the values from last time. Anything you set at install time and do not pass again is gone. Helm still reports success, because from its point of view you got what you asked for.

So this module covers three things. Where the old settings really live. What the value flags really do. And why an upgrade needs one more step after mission control itself is new.

## Learning objectives

After this module you can:

- Say where Helm stores a release's manifests and values, and read an older revision's values back out of the cluster.
- Explain how `helm upgrade` computes values, and predict what `--reuse-values` and `--reset-values` do.
- Recover settings that exist only inside a release, and rebuild a values file from them.
- Upgrade `base`, `istiod` and a gateway to a new version in the right order without losing mesh settings.
- Spot version skew between the control plane and the data plane with `istioctl version` and `istioctl proxy-status`, and finish the upgrade.
- Roll a release back to an earlier revision, and say what the rollback leaves untouched.

## Before you start

Every mission starts with a pre-flight check, astronaut. Make sure you have the knowledge this module expects, and know what is waiting in your playground.

### What you should already know

- **Kubernetes basics.** Namespaces, Deployments, Secrets, ConfigMaps, and `kubectl rollout restart`.
- **Installing Istio with Helm.** Istio comes as three Helm charts: `istio/base` (the Custom Resource Definitions, or CRDs, which teach the cluster Istio's object kinds), `istio/istiod` (mission control) and `istio/gateway` (a spaceport gate). You install them in that order, and `helm get values` shows what a release was given.
- **What `meshConfig` is.** It holds the mesh-wide settings, the fleet's standing orders. They land in the `istio` ConfigMap in `istio-system`.

### What is in your playground

Your playground is a training solar system: one `kind` cluster with **`helm` 3** and **`istioctl` 1.29.8** ready to use, and the `istio` chart repository already added.

**Istio 1.29.8 is installed as three Helm releases**, each at revision 1:

| Release | Namespace | Chart |
| --- | --- | --- |
| `istio-base` | `istio-system` | `istio/base` |
| `istiod` | `istio-system` | `istio/istiod` |
| `istio-ingressgateway` | `istio-ingress` | `istio/gateway` |

One workload with a sidecar, `notification-service`, runs in the `default` namespace.

One detail is on purpose and matters for the whole module. `istiod` was installed with a **values file that is no longer on disk**. Access logging is on, autoscaling is off, and there are fixed resource requests. The only record of that is inside the release. You will meet this situation far more often than a clean one.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Work through the parts in this order. The mission comes right after the part it practises.

1. [Where A Release Lives](./course-01-where-a-release-lives.md): the Secret behind every release, revision numbers, and the read commands that tell you what a cluster runs and how it was configured.
2. [How `helm upgrade` Computes Values](./course-02-how-upgrade-computes-values.md): the default value handling, `--reuse-values` and `--reset-values`, a setting lost on purpose, and getting a values file back from an older revision.
3. [Upgrading In Order And Finishing The Job](./course-03-upgrading-in-order-and-finishing.md): the chart order, version skew, and the data plane restart that really completes the upgrade.
4. [Rolling Back And A Safe Procedure](./course-04-rolling-back-and-a-safe-procedure.md): what `helm rollback` restores and what it does not, and a step-by-step upgrade procedure.
   - Mission: [Upgrade And Reconfigure Istio With Helm](./labs/lab-01/question.md)
5. [Wrap-Up: Mission Debrief](./course-05-wrap-up.md)

## Why this matters

Istio has two upgrade strategies. A **canary** upgrade builds a second mission control next to the first and moves planets over slowly. An **in-place** upgrade replaces the one mission control in the same building. A Helm version bump behaves like an in-place upgrade: one control plane, replaced.

The Helm path fails in its own way. `istioctl install` builds the cluster to match a file you can read. `helm upgrade` builds it to match the arguments you typed this time, on top of an earlier state you may not have. Learn where that state lives and how to keep it, and an upgrade stops being a gamble.
