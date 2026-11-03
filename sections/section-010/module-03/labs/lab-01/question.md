# Question

Solve this question on: `terminal`

Istio 1.30.5 is installed with the `default` profile. `istioctl` 1.30.5 is on your PATH. The namespace `shop` runs two workloads, `notification-service` (nginx, with a Service on port `80`) and `tester` (curl). The `shop` namespace carries the label `istio-injection=enabled`, and a `VirtualService` named `notification-route` routes requests for `notification-service`.

The on-call team reports that the mesh in `shop` "does not look right", but nobody knows what is wrong.

1.  Run `istioctl analyze` for the `shop` namespace and read every message it prints.
2.  Fix every problem the analysis reports. Fix the `VirtualService` in place: do not delete it. Keep both Deployments and the Service.
3.  Run `istioctl analyze -n shop` again. It must report `No validation issues found`.
4.  Run `istioctl verify-install` and read its result. It checks that the installed control plane matches what the cluster should hold.
5.  Send a request from the `tester` pod to `http://notification-service/`. It must return HTTP `200`.

The grader checks that both pods have an `istio-proxy` container, that `notification-route` sends traffic to an existing Service, that the analysis is clean and that the request returns `200`.
