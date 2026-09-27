# Question

Solve this question on: `terminal`

Istio 1.30.5 is installed with the **`ambient`** profile: `istiod` plus the `istio-cni-node` and `ztunnel` DaemonSets. `istioctl` 1.30.5 is on your PATH.

Namespace `ambient-demo` is **not enrolled** and runs two workloads, `notification-service` (nginx) and `tester`. Each pod has exactly one container.

1.  Enroll `ambient-demo` into the ambient mesh using the correct dataplane-mode label.
2.  Do it **without recreating any pod**. Before you started, the bootstrap recorded every pod's `metadata.uid` in the ConfigMap `ambient-demo/lab-baseline`. The grader compares the live UIDs against it — a `rollout restart`, a `kubectl delete pod`, or anything else that replaces a pod will fail the check. This is not an artificial constraint; it is the headline property of ambient mode, and the reason enrollment is reversible in a way sidecar injection is not.
3.  Do **not** inject sidecars. `ambient-demo` must carry no `istio-injection` label, and every pod must still have exactly one container. In ambient mode a meshed pod is never modified, which is also why counting containers cannot tell you whether a workload is in the mesh.
4.  Confirm the enrollment took effect by checking what **ztunnel** knows — both workloads must be reported with the `HBONE` protocol.
5.  Leave the `lab-baseline` ConfigMap in place and leave both Deployments and the Service unchanged.
