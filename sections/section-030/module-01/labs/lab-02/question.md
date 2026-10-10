# Question

Solve this question on: `terminal`

Istio **1.29.8** is installed as three Helm releases: `istio-base` and `istiod` in `istio-system`, and `istio-ingressgateway` in `istio-ingress`. One workload with a sidecar proxy, `notification-service`, runs in the `default` namespace. `helm` 3 and `istioctl` 1.29.8 are on your PATH.

Revision 1 of the `istiod` release was installed with a values file that is no longer on disk. It turned on access logging to `/dev/stdout`, switched off autoscaling of the control plane, set `istiod` to request `100m` CPU and `256Mi` memory, and set every injected sidecar to request `10m` CPU and `64Mi` memory.

Then someone ran `helm upgrade` on `istiod` with `--reset-values` and no values file. That created revision 2, which reset all of those settings to the chart defaults. After that, the `notification-service` workload was restarted, so its sidecar now has the chart-default resource requests too.

Undo the bad change:

1.  Read the history of the `istiod` release and find the last good revision.
2.  Roll the `istiod` release back to that revision with **`helm rollback`**. Do not run a new `helm upgrade` or reinstall the release, even with a rebuilt values file.
3.  Leave `istio-base` and `istio-ingressgateway` as they are. Only `istiod` had the bad upgrade.
4.  Make sure the settings of revision 1 are live again: access logging to `/dev/stdout` in the `istio` ConfigMap, no HorizontalPodAutoscaler for `istiod`, and `istiod` requesting `100m` CPU and `256Mi` memory.
5.  Bring the data plane in line. `helm rollback` does not restart pods, so the running sidecar keeps the requests it was injected with. When you are done, the running `notification-service` pod must be `Ready` and its `istio-proxy` container must request `10m` CPU and `64Mi` memory.

Leave `notification-service` in place. Do not delete and recreate the Deployment, and do not add a second one.

The grader reads the Helm release records (the latest `istiod` revision must be a rollback to revision 1), the `istiod` Deployment, the `istio` ConfigMap, the HorizontalPodAutoscalers in `istio-system` and the running pod in `default`.
