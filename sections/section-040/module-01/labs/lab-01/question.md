# Question

Solve this question on: `terminal`

Astronaut, Istio 1.30.5 is installed with the **`ambient`** profile: `istiod` plus the `istio-cni-node` and `ztunnel` DaemonSets. In ambient mode no ship carries its own communications officer; a shared relay tower (ztunnel) on each node does the job. `istioctl` 1.30.5 is on your PATH.

The planet (namespace) `ambient-demo` is **not enrolled** in the mesh. It runs two workloads, `notification-service` (nginx) and `tester`. Each pod has exactly one container.

1.  Enroll `ambient-demo` in the ambient mesh, using the correct dataplane-mode label.
2.  Do it **without recreating any pod**. Before you started, the bootstrap saved every pod's `metadata.uid` in the ConfigMap `ambient-demo/lab-baseline`. The grader compares the live UIDs with it. A `rollout restart`, a `kubectl delete pod`, or anything else that replaces a pod fails this check. Ambient enrollment never needs a restart, and that is exactly what this requirement proves.
3.  Do **not** inject sidecars. `ambient-demo` must carry no `istio-injection` label, and every pod must still have exactly one container. In ambient mode a meshed pod is never changed, so counting containers cannot tell you whether a workload is in the mesh.
4.  Confirm that the enrollment worked by checking what **ztunnel** knows. Both workloads must be reported with the `HBONE` protocol.
5.  Leave the `lab-baseline` ConfigMap in place, and leave both Deployments and the Service unchanged.

The grader also checks that the `ztunnel` and `istio-cni-node` DaemonSets each have at least one ready pod.
