# Question

Solve this question on: `terminal`

Istio 1.30.5 is installed with the `default` profile and `istioctl` 1.30.5 is on your PATH. The namespace `edge-demo` runs `notification-service` (nginx) and a `tester` pod. A `Gateway` and a `VirtualService` publish `notification-service` through the Istio ingress gateway (Deployment `istio-ingressgateway` in `istio-system`) on port `80`.

The cluster has no load balancer, so the gateway Service of type `LoadBalancer` never gets an external address. Change the installation so the gateway is reachable on a fixed node port, and size it for more traffic.

1.  Write an `IstioOperator` file and install it with `istioctl install`. Keep `profile: default` and keep the ingress gateway enabled.
2.  The gateway Service `istio-ingressgateway` must have type `NodePort`, and its port `80` must use node port `30080` (container target port `8080`). Keep the ports `15021` and `443` in the Service as well.
3.  The `HorizontalPodAutoscaler` of the gateway must have `minReplicas: 2` and `maxReplicas: 4`.
4.  The gateway container must request `150m` CPU and `192Mi` memory.
5.  Prove it: a request from the `tester` pod to `http://<node-internal-ip>:30080/` must return HTTP `200`. Get the address with `kubectl get nodes -o wide`.

Do not change the `Gateway`, the `VirtualService` or the workloads. Do not install the gateway with Helm: this cluster is owned by `istioctl`.
