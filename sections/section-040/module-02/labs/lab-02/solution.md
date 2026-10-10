# Solution Walkthrough

Follow these steps to replace the namespace waypoint with a service waypoint, so that only `notification-service` goes through layer 7 and `reporting-service` stays on layer 4.

---

## Step 1: Look at the starting state

List the waypoints in the namespace and the namespace labels:

```sh
istioctl waypoint list -n ambient-l7
kubectl get ns ambient-l7 --show-labels
```

```text
NAME         REVISION     TRAFFIC TYPE     PROGRAMMED
waypoint     default      none             True
NAME         STATUS   AGE   LABELS
ambient-l7   Active   16s   istio.io/dataplane-mode=ambient,istio.io/use-waypoint=waypoint,kubernetes.io/metadata.name=ambient-l7
```

There is one waypoint, `waypoint`, with `PROGRAMMED` `True`, and the namespace carries `istio.io/dataplane-mode=ambient` and `istio.io/use-waypoint=waypoint`. `TRAFFIC TYPE none` means the `Gateway` has no `istio.io/waypoint-for` label, and Istio then uses it for Service traffic, the default. The second label enrolls the whole namespace, so ztunnel sends the traffic of every Service in it through `waypoint`.

Confirm that from ztunnel's own view:

```sh
istioctl ztunnel-config service | grep ambient-l7
```

```text
ambient-l7   notification-service        10.96.109.85  waypoint 1/1
ambient-l7   reporting-service           10.96.189.182 waypoint 1/1
ambient-l7   waypoint                    10.96.72.53   None     1/1
```

`grep` removes the header; the columns are `NAMESPACE`, `SERVICE NAME`, `SERVICE VIP`, `WAYPOINT` and `ENDPOINTS`. The `WAYPOINT` column names `waypoint` on both the `notification-service` row and the `reporting-service` row. `reporting-service` pays for the extra hop and gets nothing from it.

---

## Step 2: Create the service waypoint

Create a second waypoint named `svc-waypoint` for Service traffic, and wait for its Deployment:

```sh
istioctl waypoint apply -n ambient-l7 --name svc-waypoint --for service
kubectl -n ambient-l7 rollout status deployment svc-waypoint --timeout=180s
```

The output looks like this (shortened: the `Waiting for deployment` lines are left out):

```text
✅ waypoint ambient-l7/svc-waypoint applied
deployment "svc-waypoint" successfully rolled out
```

`--for service` writes the label `istio.io/waypoint-for: service` on the new `Gateway`, which tells Istio that this waypoint handles traffic addressed to Services. Leave out `--enroll-namespace`: this waypoint must serve one Service, not the whole namespace.

---

## Step 3: Point notification-service at it

Add the label to the Service:

```sh
kubectl -n ambient-l7 label service notification-service istio.io/use-waypoint=svc-waypoint
istioctl waypoint list -n ambient-l7
```

```text
service/notification-service labeled
NAME             REVISION     TRAFFIC TYPE     PROGRAMMED
svc-waypoint     default      service          True
waypoint         default      none             True
```

The label on the Service beats the label on the namespace, so ztunnel now sends `notification-service` traffic through `svc-waypoint`. Do this step before Step 4, so `notification-service` never loses its layer 7 route in between.

---

## Step 4: Remove the namespace enrollment and the namespace waypoint

Remove the namespace label (the trailing `-` removes it), then delete the namespace waypoint:

```sh
kubectl label namespace ambient-l7 istio.io/use-waypoint-
istioctl waypoint delete waypoint -n ambient-l7
```

```text
namespace/ambient-l7 unlabeled
waypoint ambient-l7/waypoint deleted
```

Now only the `notification-service` Service points at a waypoint. Do not add the label to `reporting-service`: it needs only layer 4, and the grader rejects a waypoint on it.

Check ztunnel's view again:

```sh
istioctl ztunnel-config service | grep ambient-l7
```

```text
ambient-l7   notification-service        10.96.109.85  svc-waypoint 1/1
ambient-l7   reporting-service           10.96.189.182 None         1/1
ambient-l7   svc-waypoint                10.96.58.79   None         1/1
```

The `WAYPOINT` column names `svc-waypoint` on the `notification-service` row and `None` on the `reporting-service` row. If the rows still name `waypoint` and `svc-waypoint` shows `0/0` endpoints, ztunnel has not received the change yet; run the command again after a few seconds.

---

## Step 5: Prove it with requests

Send one request to each Service from `tester`:

```sh
kubectl -n ambient-l7 exec deploy/tester -- curl -s -o /dev/null -D - http://notification-service/ | grep -i -E '^(HTTP/|server:|x-envoy-upstream-service-time:|x-processed-by:)'
kubectl -n ambient-l7 exec deploy/tester -- curl -s -i http://reporting-service/ | head -3
```

```text
HTTP/1.1 200 OK
server: istio-envoy
x-envoy-upstream-service-time: 1
x-processed-by: waypoint
HTTP/1.1 200 OK
Server: nginx/1.27.5
Date: Sat, 10 Oct 2026 01:07:40 GMT
```

The first command prints the response headers (`-D -`), drops the body, and keeps the status line and three headers. The first response is `200` with `server: istio-envoy` and `x-processed-by: waypoint`: the `HTTPRoute` attaches to the Service, so it follows the Service to whichever waypoint serves it. The second response is `200` with nginx's own `Server` header and no `x-processed-by` header: no Envoy is in the path of `reporting-service`. Both requests still travel over HBONE, the mutual TLS tunnel of ztunnel, so `reporting-service` keeps mutual TLS and identity.

---

## Step 6: Submit

Send the lab for grading:

```sh
astrona submit
```

The grader checks that:

- the namespace still carries `istio.io/dataplane-mode=ambient`;
- the `svc-waypoint` Gateway is class `istio-waypoint`, handles Service traffic, is `Programmed: True`, and has a ready Deployment;
- the `notification-service` Service carries `istio.io/use-waypoint=svc-waypoint`, and neither the `reporting-service` Service nor the namespace carries an `istio.io/use-waypoint` label;
- the `waypoint` Gateway no longer exists;
- the `HTTPRoute` still attaches to `Service/notification-service`;
- ztunnel's service view names `svc-waypoint` for `notification-service` and no waypoint for `reporting-service`;
- a request to `notification-service` returns `200` with `x-processed-by: waypoint`, and a request to `reporting-service` returns `200` without `server: istio-envoy`.

---

## Common mistakes

*   **Labelling the Service and stopping.** `notification-service` moves to `svc-waypoint`, but the namespace is still enrolled, so `reporting-service` still goes through `waypoint`.
*   **Deleting every waypoint.** `reporting-service` is fine, but `notification-service` loses its layer 7 route and the `x-processed-by` header disappears, with no error.
*   **Removing the namespace label before labelling the Service.** It works in the end, but `notification-service` has no layer 7 for a moment. On a real cluster that gap matters.
*   **Labelling `reporting-service` too.** Then both Services pay for the extra hop again, which is what the task removes.
*   **Deleting or changing the `HTTPRoute`.** The route attaches to the Service, not to a waypoint, so it needs no change when the waypoint changes.
