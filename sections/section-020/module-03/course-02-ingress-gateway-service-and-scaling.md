# Shaping The Ingress Gateway Service And Scaling

An ingress gateway is an Envoy proxy that receives traffic from outside the cluster. Whether that traffic can arrive depends on its Kubernetes Service. This part changes the Service type, sets the autoscaler and the resource requests through the `IstioOperator` file, and proves each change on the live objects.

## Why the default Service does not work on kind

The `default` profile creates the gateway Service with the type `LoadBalancer`. A cloud provider answers that type with an external address. The `kind` cluster has no load balancer, so the address never arrives. Check it:

<!-- astrona:playground:renew -->

```sh
kubectl -n istio-system get service istio-ingressgateway
```

The `EXTERNAL-IP` column shows `<pending>`. The cluster still works from the inside. A `NodePort` Service opens a fixed port on every node, and that is reachable without a load balancer.

## Write the overlay

Three settings change in one file. The Service gets type `NodePort` with a fixed node port, the autoscaler gets its bounds and the gateway container gets resource requests. Save this as `istio-gateway.yaml`:

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  components:
    ingressGateways:
      - name: istio-ingressgateway
        enabled: true
        k8s:
          resources:
            requests:
              cpu: 150m
              memory: 192Mi
          hpaSpec:
            minReplicas: 2
            maxReplicas: 4
          service:
            type: NodePort
            ports:
              - name: status-port
                port: 15021
                targetPort: 15021
              - name: http2
                port: 80
                targetPort: 8080
                nodePort: 30080
              - name: https
                port: 443
                targetPort: 8443
```

The Service port `80` forwards to the container port `8080`, because the gateway proxy does not run as root and cannot listen below port 1024. The overlay lists all three ports, so the file shows the whole Service. The `nodePort` must be inside the range `30000` to `32767`.

## Render, apply and check

Render first and look for the node port:

```sh
istioctl manifest generate -f istio-gateway.yaml | grep -n 'nodePort'
```

Apply it:

```sh
istioctl install -f istio-gateway.yaml -y
```

Then check the result:

```sh
kubectl -n istio-system get service,hpa istio-ingressgateway
kubectl -n istio-system get deployment istio-ingressgateway -o jsonpath='{.spec.template.spec.containers[0].resources.requests}{"\n"}'
```

The Service type is `NodePort` and port 80 maps to `30080`. The HPA reports the minimum and maximum you set. The requests show `150m` and `192Mi`. `istioctl install` reconciled the objects, so the older Service and HPA values are replaced by these.

## Send a request through the node port

Get the internal address of the node, then request the service published in `gw-demo` from the `tester` pod:

```sh
kubectl get nodes -o wide
kubectl -n gw-demo exec deploy/tester -- curl -s -o /dev/null -w '%{http_code}\n' http://<node-internal-ip>:30080/
```

Replace `<node-internal-ip>` with the `INTERNAL-IP` of the node. The result is `200`: the request reached the node port, the Service sent it to the gateway pod, and the `Gateway` and `VirtualService` routed it to `notification-service`.

## What the autoscaler does and does not do

`hpaSpec` sets the bounds of the `HorizontalPodAutoscaler` object. The autoscaler needs a metrics source, such as the Kubernetes metrics server, to scale by load. If the cluster has none, the HPA object still exists with your bounds, but no scaling happens. For a fixed number of replicas, use `replicaCount` instead, and do not combine it with `hpaSpec`.

You can now reshape the ingress gateway with the `IstioOperator` file: its Service, its scaling and its resources, rendered before it is applied and proved afterwards. A change that is only a field in a file can be repeated on any cluster.

## Common pitfalls

> [!WARNING]
> **Leaving the Service as `LoadBalancer` on `kind`.** The external address never arrives, so nothing outside can connect. Use `NodePort`.
>
> **Listing only the changed port.** Write all the ports the gateway needs, so the Service in the file is the Service you get.
>
> **Setting `replicaCount` and `hpaSpec` together.** The autoscaler overrides the replica count, so the number you set is ignored.

## Your mission: Customize The Ingress Gateway With IstioOperator Lab

You can now change the Service, the scaling and the resources of the ingress gateway through the `IstioOperator` file. The lab asks you to expose the gateway on a fixed node port, set its autoscaler and requests, and prove it with a request that returns `200`.

The lab runs on its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-013-playground-020-03
```

Then start the lab. The task is on the next page; solve it on your own first:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-020/module-03/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-03/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-013-lab-020-03
astrona start ats-013-playground-020-03
```
