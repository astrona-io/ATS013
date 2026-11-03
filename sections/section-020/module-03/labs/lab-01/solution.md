# Solution Walkthrough

This lab is UNTESTED: the steps follow the documented behaviour of the commands, and no output is copied here.

---

## Step 1: Look at the gateway as installed

```sh
kubectl -n istio-system get deployment,service,hpa istio-ingressgateway
```

The Service has type `LoadBalancer`, and its `EXTERNAL-IP` stays `<pending>` because `kind` has no load balancer. The `HorizontalPodAutoscaler` (HPA) shows the minimum and maximum number of replicas the profile sets.

You can also print what the profile holds for the gateway:

```sh
istioctl profile dump default --config-path components.ingressGateways
```

---

## Step 2: Write the overlay

All three changes live under `components.ingressGateways[].k8s`. The gateway is matched by its `name`. Save this as `istio-gateway.yaml`:

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

Port `80` on the Service forwards to the container port `8080`, because the gateway proxy does not run as root and cannot bind to a port below 1024.

---

## Step 3: Check the render, then apply

```sh
istioctl manifest generate -f istio-gateway.yaml | grep -n 'nodePort'
istioctl install -f istio-gateway.yaml -y
kubectl -n istio-system rollout status deployment/istio-ingressgateway
```

The first command prints a line for the node port `30080`. If it prints nothing, the overlay did not reach the Service: check the indentation under `k8s`.

---

## Step 4: Check the result

```sh
kubectl -n istio-system get service,hpa istio-ingressgateway
kubectl -n istio-system get deployment istio-ingressgateway \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests}{"\n"}'
```

The Service type is `NodePort` and port `80` shows `80:30080/TCP`. The HPA shows `MINPODS 2` and `MAXPODS 4`. The requests show `150m` and `192Mi`.

---

## Step 5: Send a request through the node port

```sh
kubectl get nodes -o wide
kubectl -n edge-demo exec deploy/tester -- curl -s -o /dev/null -w '%{http_code}\n' http://<node-internal-ip>:30080/
```

Put the `INTERNAL-IP` of the node in place of `<node-internal-ip>`. The result must be `200`. If it fails right after the rollout, wait a few seconds and send the request again.

---

## Step 6: Submit

```sh
astrona submit -c sections/section-020/module-03/labs/lab-01
```
