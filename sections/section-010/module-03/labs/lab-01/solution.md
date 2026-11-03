# Solution Walkthrough

This lab is UNTESTED: the steps are written from the commands' documented behaviour, and no output is copied here. Run each command and compare what you see with the description.

---

## Step 1: Run the analysis

```sh
istioctl analyze -n shop
```

`istioctl analyze` reads the live cluster and prints one message for each problem, with a code. Expect two kinds of message in `shop`:

- `IST0103`: a pod in an injection-enabled namespace has no sidecar. The label was set after the pods were created, and injection only happens when a pod is created.
- `IST0101`: the `VirtualService` `notification-route` refers to the host `notification-svc`, which does not exist in the namespace.

---

## Step 2: Give the pods their sidecar

Create the pods again so the injection webhook runs:

```sh
kubectl -n shop rollout restart deployment/notification-service deployment/tester
kubectl -n shop rollout status deployment/notification-service
kubectl -n shop rollout status deployment/tester
kubectl -n shop get pods
```

Each pod now shows `2/2` containers ready: the application and `istio-proxy`.

---

## Step 3: Fix the destination host

Look at the route:

```sh
kubectl -n shop get virtualservice notification-route -o yaml
```

The destination host is `notification-svc`. The Service is called `notification-service`. Save the corrected object as `virtualservice-notification-route.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: notification-route
  namespace: shop
spec:
  hosts:
    - notification-service
  http:
    - route:
        - destination:
            host: notification-service
```

Apply it:

```sh
kubectl apply -f virtualservice-notification-route.yaml
```

---

## Step 4: Analyze again and verify the install

```sh
istioctl analyze -n shop
istioctl verify-install
```

The first command must say `No validation issues found`. If it still prints a message, read the code and the object it names. The second command checks the installed components; read its last line.

---

## Step 5: Send the request

```sh
kubectl -n shop exec deploy/tester -c tester -- curl -s -o /dev/null -w '%{http_code}\n' http://notification-service/
```

The result must be `200`.

---

## Step 6: Submit

```sh
astrona submit -c sections/section-010/module-03/labs/lab-01
```

If the grader reports a sidecar problem, a pod was not created again after the label. If it reports analysis issues, run `istioctl analyze -n shop` and fix what it prints.
