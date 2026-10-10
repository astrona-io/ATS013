# Question

Solve this question on: `terminal`

`notification-service` must open plain connections to a PostgreSQL database outside the mesh, on port `5432`. The sidecar proxy must not touch that traffic. All other traffic of the workload must stay in the mesh.

Istio 1.30.5 is installed with the `default` profile. The namespace `inject-demo` carries `istio-injection=enabled` and runs one Deployment, `notification-service`, with a Service on port `80`. Its pod already has the `istio-proxy` sidecar container, and the `istio-init` init container currently captures every outbound port.

Produce this end state:

1.  Outbound port **`5432`**, and no other port, is excluded from traffic capture for `notification-service`, with the annotation `traffic.sidecar.istio.io/excludeOutboundPorts` set to `"5432"`.
2.  The annotation is on the **pod template** (`spec.template.metadata.annotations`). Injection only sees the pod, so an annotation on the Deployment's own `metadata.annotations` applies cleanly and does nothing.
3.  The running `notification-service` pod still has the `istio-proxy` sidecar, is `Ready`, and its `istio-init` container runs `istio-iptables` with `-o 5432`.
4.  Do not turn off injection for the workload, do not exclude whole address ranges, and keep the label `istio-injection=enabled` on `inject-demo`.
5.  `inject-demo` still holds exactly one Deployment, `notification-service`. Do not delete and recreate it, and do not rename it.

The grader reads the live cluster: the namespace label, the Deployment and its pod template annotations and labels, and the containers, readiness and `istio-init` arguments of every running `notification-service` pod.
