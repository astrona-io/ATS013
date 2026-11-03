# Sidecar And Ambient Mode Side By Side

A mesh that runs both modes needs a clear rule for which pod uses which. The rule is short, but the signs of each mode look different in `kubectl` and in `istioctl`, and a wrong guess sends you debugging the wrong proxy. This part compares the two modes on the playground cluster, where both run at once.

## Two labels, two components

Each mode is selected by a namespace label, and a different component acts on it:

| | Sidecar mode | Ambient mode |
| --- | --- | --- |
| Namespace label | `istio-injection=enabled` (or `istio.io/rev=<revision>`) | `istio.io/dataplane-mode=ambient` |
| Component that acts | The injection webhook in `istiod`, at pod creation | `istio-cni-node` and `ztunnel`, at any time |
| Proxy | An Envoy `istio-proxy` container in every pod | One `ztunnel` for each node |
| What changes | The pod spec | Node-level redirection and ztunnel state |

Show the labels of the two namespaces:

<!-- astrona:playground:renew -->

```sh
kubectl get namespace legacy-shop new-shop --show-labels
```

`legacy-shop` has `istio-injection=enabled`, and `new-shop` has `istio.io/dataplane-mode=ambient`. The ambient profile installed `istiod`, and that `istiod` still runs the injection webhook, so both labels work on this cluster.

## Telling the modes apart

In sidecar mode the proof is in the pod. Compare the pods of both namespaces:

```sh
kubectl -n legacy-shop get pods
kubectl -n new-shop get pods
```

The pods in `legacy-shop` show `2/2` (the application and `istio-proxy`), and the pods in `new-shop` show `1/1`. The container count answers the question only for sidecar mode. A pod with `1/1` can be in the ambient mesh or outside the mesh, so for ambient mode you ask ztunnel:

```sh
istioctl ztunnel-config workload | grep -E 'legacy-shop|new-shop'
istioctl proxy-status
```

The first command lists the ambient workloads with `HBONE` as their protocol. The second lists the Envoy proxies that are connected to `istiod`: the sidecars of `legacy-shop`. The pods of `new-shop` have no Envoy of their own, so they are not in that list.

## The two modes reach each other

Both modes use the same `istiod` and issue the same kind of workload identity, so a sidecar pod can call an ambient service and the other way round. Test both directions:

```sh
kubectl -n legacy-shop exec deploy/tester -c tester -- curl -s -o /dev/null -w '%{http_code}\n' http://notification-service.new-shop/
kubectl -n new-shop exec deploy/tester -c tester -- curl -s -o /dev/null -w '%{http_code}\n' http://notification-service.legacy-shop/
```

Both requests return `200`. This is what makes a gradual migration possible: the callers do not have to move at the same time as the services they call.

## A pod uses one mode

A pod that has a sidecar is not captured by ztunnel. The sidecar already handles all traffic of the pod, so ambient redirection for that pod is skipped. The consequence matters for a migration: if you add the ambient label to a namespace whose pods already have sidecars, those pods keep using their sidecars until they are created again without one.

## Choosing a mode

The choice follows from what the workload needs:

- Choose **ambient mode** when most workloads need only mutual TLS and layer 4 policy, and you want to join the mesh without restarting pods, with one proxy per node instead of one per pod.
- Choose **sidecar mode** when a workload needs layer 7 features on every connection with the lowest hop count, or when the cluster cannot run the `istio-cni` agent that ambient mode requires.
- In ambient mode, layer 7 features need a waypoint proxy, which you add only where you need it.

You now know how the two modes are selected, how to tell them apart and why they can talk to each other. The open question is the move itself: what happens to a namespace that goes from one mode to the other, and in which order.

## Common pitfalls

> [!WARNING]
> **Counting containers in ambient mode.** `1/1` does not mean the pod is outside the mesh. Use `istioctl ztunnel-config workload`.
>
> **Expecting an ambient label to remove sidecars.** Running pods keep their sidecar until they are created again.
>
> **Assuming one cluster means one mode.** The mode is chosen for each namespace, so check the labels of the namespace first.
