# Solution Walkthrough

This lab is UNTESTED: the steps follow the documented behaviour of the commands, and no output is copied here.

---

## Step 1: Look at the starting point

```sh
kubectl get namespace sidecar-shop --show-labels
kubectl -n sidecar-shop get pods
kubectl -n sidecar-shop get configmap lab-baseline -o jsonpath='{.data.pod-uids}{"\n"}'
```

The namespace carries `istio-injection=enabled`, and each pod shows `2/2` containers ready: the application and `istio-proxy`. The ConfigMap holds the pod UIDs the grader compares with at the end.

---

## Step 2: Swap the labels

Remove the injection label (the trailing `-` removes a label) and add the ambient label:

```sh
kubectl label namespace sidecar-shop istio-injection-
kubectl label namespace sidecar-shop istio.io/dataplane-mode=ambient
```

The pods that are already running keep their sidecars. A pod that has a sidecar is not captured by ztunnel, and the label change does not remove a container from a running pod.

---

## Step 3: Create the pods again

```sh
kubectl -n sidecar-shop rollout restart deployment/notification-service deployment/tester
kubectl -n sidecar-shop rollout status deployment/notification-service
kubectl -n sidecar-shop rollout status deployment/tester
kubectl -n sidecar-shop get pods
```

The new pods are created in a namespace without the injection label, so the webhook adds no sidecar. Each pod shows `1/1`. Do the label swap first: a restart before it would create the pods with sidecars again.

---

## Step 4: Check membership and the request

```sh
istioctl ztunnel-config workload | grep sidecar-shop
kubectl -n sidecar-shop exec deploy/tester -c tester -- curl -s -o /dev/null -w '%{http_code}\n' http://notification-service/
```

The `PROTOCOL` column must read `HBONE` for both workloads, and the request must return `200`. If the rows read `TCP`, run the command again after a few seconds.

---

## Step 5: Submit

```sh
astrona submit -c sections/section-040/module-03/labs/lab-01
```
