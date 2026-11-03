# Migrating A Namespace To Ambient Mode

Moving a namespace from sidecars to ambient mode removes one proxy from every pod. It is a small change in labels, but the order of the steps decides whether traffic keeps working. This part migrates `legacy-shop` on the playground and checks each step.

## Plan the order

Three things change: the namespace labels, the pods and the policies that depend on layer 7. The safe order is:

1. Swap the labels: remove the injection label and add the ambient label.
2. Create the pods again, so the new pods have no sidecar.
3. Check membership and traffic.

Do the labels first. A restart before the label swap creates the pods with sidecars again.

## Swap the labels

Remove the injection label, and add the ambient label. The trailing `-` in the first command removes a label:

<!-- astrona:playground:renew -->

```sh
kubectl label namespace legacy-shop istio-injection-
kubectl label namespace legacy-shop istio.io/dataplane-mode=ambient
kubectl -n legacy-shop get pods
```

The pods still show `2/2`. The labels changed, but the running pods keep their sidecar, because a label change never removes a container from a running pod. The traffic of these pods still goes through their sidecars.

## Create the pods again

Restart the Deployments. The Kubernetes controller creates new pods, and the injection webhook finds no injection label and adds no sidecar:

```sh
kubectl -n legacy-shop rollout restart deployment/notification-service deployment/tester
kubectl -n legacy-shop rollout status deployment/notification-service
kubectl -n legacy-shop rollout status deployment/tester
kubectl -n legacy-shop get pods
```

Each pod now shows `1/1`. A rolling restart replaces the pods one at a time, so a Deployment with more than one replica keeps serving during the move.

## Check membership and traffic

Ask ztunnel, and send a request:

```sh
istioctl ztunnel-config workload | grep legacy-shop
kubectl -n legacy-shop exec deploy/tester -c tester -- curl -s -o /dev/null -w '%{http_code}\n' http://notification-service/
```

The `PROTOCOL` column reads `HBONE` for both workloads, and the request returns `200`. If the rows read `TCP`, ztunnel has not yet received the new pods: run the command again after a few seconds.

## What does not move by itself

Policies that match on layer 7 fields, such as an HTTP method or path, were enforced by the sidecar. ztunnel works at layer 4 and cannot read HTTP, so after the move such a policy is accepted by the API server and no longer enforced. For every layer 7 policy in the namespace, add a waypoint proxy, or confirm that a layer 4 rule is enough. Policies that match on a principal, a namespace or a port keep working in ztunnel.

## Going back

The same steps work in the other direction. Remove the ambient label, add `istio-injection=enabled`, and restart the Deployments so the webhook adds the sidecars. Because the two modes reach each other, you can stop half way and run both modes for as long as you need.

You can now migrate a namespace from sidecar to ambient mode, in the right order, and prove it with the container count, `istioctl ztunnel-config workload` and a request. The one remaining task is to find which policies need a waypoint.

## Common pitfalls

> [!WARNING]
> **Restarting before the label swap.** The new pods get a sidecar again. Swap the labels first.
>
> **Leaving `istio.io/rev` on the namespace.** A revision label also asks for a sidecar. Remove it with the injection label.
>
> **Forgetting layer 7 policies.** After the move, an `AuthorizationPolicy` on a method or a path does nothing without a waypoint.

## Your mission: Migrate A Namespace From Sidecar To Ambient Mode Lab

You can now move a namespace from sidecars to ambient mode. The lab asks you to migrate a namespace, remove every sidecar and prove it with ztunnel and a request.

The lab runs on its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-013-playground-040-03
```

Then start the lab. The task is on the next page; solve it on your own first:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-040/module-03/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/module-03/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-013-lab-040-03
astrona start ats-013-playground-040-03
```
