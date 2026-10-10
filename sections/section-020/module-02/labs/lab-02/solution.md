# Solution Walkthrough

Follow these steps to preview the change with `istioctl kube-inject`, set the exclusion on the pod template, and prove that the new pod still has its sidecar and carries the exclusion in its traffic rules.

---

## Step 1: Check the starting state

Sidecar injection adds two init containers to each new pod in an injected namespace: `istio-init` and `istio-proxy`, the Envoy sidecar proxy. Istio 1.30 runs `istio-proxy` as a native sidecar, an init container with `restartPolicy: Always` that keeps running beside the application. `istio-init` runs `istio-iptables`, which writes `iptables` rules that send all outbound traffic of the pod to the proxy on port `15001`.

Confirm that the namespace is injected and that the pod has its sidecar:

```sh
kubectl get ns inject-demo --show-labels
kubectl -n inject-demo get pods -o custom-columns='POD:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name'
```

```text
NAME          STATUS   AGE   LABELS
inject-demo   Active   6s    istio-injection=enabled,kubernetes.io/metadata.name=inject-demo
POD                                     INIT                     CONTAINERS
notification-service-76f869bb97-gfc4v   istio-init,istio-proxy   notification-service
```

The namespace has the label `istio-injection=enabled`, and the `notification-service` pod has `istio-init` and `istio-proxy`. `istio-init` is the first init container, so `initContainers[0]` in the next command reads its arguments.

Now look for an outbound port exclusion in the current `istio-init` arguments:

```sh
kubectl -n inject-demo get pod -l app=notification-service \
  -o jsonpath='{.items[0].spec.initContainers[0].args}{"\n"}' | tr ',' '\n' | grep -A1 -- '-o'
```

The command prints nothing, because `grep` finds no match. There is no `-o` argument yet, so the rules capture every outbound port, including `5432`.

---

## Step 2: Preview the change with kube-inject

`istioctl kube-inject` makes the same change injection would make, on your machine, using the live cluster's injection settings, and prints the result instead of applying it. Save the Deployment to a file:

```sh
kubectl -n inject-demo get deployment notification-service -o yaml > notification-service.yaml
```

Open `notification-service.yaml` in an editor and add the annotation under `spec.template.metadata`, next to the existing `labels`:

```yaml
spec:
  template:
    metadata:
      annotations:
        traffic.sidecar.istio.io/excludeOutboundPorts: "5432"
```

Then render it and read the `istio-init` arguments. The fields of each container are sorted by name, so the `args` list comes before `name: istio-init`; print it from the `initContainers:` line:

```sh
istioctl kube-inject -f notification-service.yaml | grep -A22 'initContainers:'
```

```text
      initContainers:
      - args:
        - istio-iptables
        - -p
        - "15001"
        - -z
        - "15006"
        - -u
        - "1337"
        - -m
        - REDIRECT
        - -i
        - '*'
        - -x
        - ""
        - -b
        - '*'
        - -d
        - 15090,15021,15020
        - -o
        - "5432"
        - --log_output_level=default:info
        image: registry.istio.io/release/proxyv2:1.30.5
```

The arguments now include `-o` followed by `"5432"`, next to `-p "15001"` and `-z "15006"`. Nothing in the cluster has changed yet; this step only shows what injection would write.

---

## Step 3: Set the annotation on the pod template

Patch the pod template of the running Deployment:

```sh
kubectl -n inject-demo patch deployment notification-service -p \
  '{"spec":{"template":{"metadata":{"annotations":{"traffic.sidecar.istio.io/excludeOutboundPorts":"5432"}}}}}'
kubectl -n inject-demo rollout status deployment notification-service --timeout=180s
```

```text
deployment.apps/notification-service patched
Waiting for deployment "notification-service" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "notification-service" rollout to finish: 1 old replicas are pending termination...
deployment "notification-service" successfully rolled out
```

Look at the patch path: `spec`, then `template`, then `metadata`, then `annotations`. That is the **pod template**. A change to the template changes its hash, so the Deployment controller starts a rollout by itself, and you do not need `kubectl rollout restart`. The new pod passes through the injection webhook, and `istiod` turns the annotation into an argument for `istio-iptables`.

The value is quoted because annotation values are strings.

---

## Step 4: Prove the exclusion and the sidecar

Read the `istio-init` arguments of the new pod:

```sh
kubectl -n inject-demo get pod -l app=notification-service \
  -o jsonpath='{.items[0].spec.initContainers[0].args}{"\n"}' | tr ',' '\n' | grep -A1 -- '-o'
```

```text
"-o"
"5432"
```

The `-o 5432` argument tells `istio-iptables` to leave outbound port `5432` out of the redirect. Connections to that port go straight from the application to the destination, without the proxy.

Then check that the workload is still in the mesh:

```sh
kubectl -n inject-demo get pods -o custom-columns='POD:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name'
istioctl proxy-status
```

```text
POD                                     INIT                     CONTAINERS
notification-service-5f49dccbcc-5grcs   istio-init,istio-proxy   notification-service
notification-service-76f869bb97-gfc4v   istio-init,istio-proxy   notification-service
NAME                                                  CLUSTER        ISTIOD                      VERSION     SUBSCRIBED TYPES
istio-ingressgateway-8cd96656f-xfzwh.istio-system     Kubernetes     istiod-5497897698-qvpg7     1.30.5      3 (CDS,LDS,EDS)
notification-service-5f49dccbcc-5grcs.inject-demo     Kubernetes     istiod-5497897698-qvpg7     1.30.5      4 (CDS,LDS,EDS,RDS)
```

The old pod is still listed for a few seconds while it stops; run the first command again and only the new pod is left. The new pod still has `istio-proxy`, and `istioctl proxy-status` lists its proxy in `inject-demo`, connected to `istiod`. Every port other than `5432` still goes through the proxy, with mTLS, policy and telemetry.

---

## Step 5: Submit

```sh
astrona submit
```

The grader checks that:

- `inject-demo` still carries `istio-injection=enabled` and holds exactly one Deployment, `notification-service`, with a ready replica.
- The pod template does not carry `sidecar.istio.io/inject: "false"`.
- `spec.template.metadata.annotations['traffic.sidecar.istio.io/excludeOutboundPorts']` is exactly `"5432"`. If the annotation is only on the Deployment's own metadata, it tells you so.
- The pod template sets none of `excludeOutboundIPRanges`, `includeOutboundIPRanges` or `excludeInboundPorts`.
- Every running `notification-service` pod has `istio-proxy`, is `Ready`, and has `-o 5432` in its `istio-init` arguments.

---

## Common mistakes

*   **Turning off injection to free one port.** `sidecar.istio.io/inject: "false"` removes the sidecar, so every port leaves the mesh. The grader rejects it.
*   **Putting the annotation on the Deployment's `metadata.annotations`.** The patch applies, nothing fails, and the pod's rules do not change. Injection only reads the pod.
*   **Excluding more than asked.** An `excludeOutboundIPRanges` of `0.0.0.0/0`, or extra ports, takes far more traffic out of the mesh than the task allows.
*   **Reading the old pod.** Until the rollout finishes, the old pod without the exclusion may still be listed. Wait for `rollout status` before you check.
