# Solution Walkthrough

Follow these steps to roll the `istiod` release back to its last good revision, prove that the original settings are live again, and restart the workload so its sidecar proxy follows the control plane.

---

## Step 1: Read the release history

`helm history` lists every revision of a release with its status and description. Read it for `istiod`:

```sh
helm history istiod -n istio-system
```

You should see two revisions: revision 1 with the status `superseded` and the description `Install complete`, and revision 2 with the status `deployed` and the description `Upgrade complete`. Both are on chart `istiod-1.29.8`, so the version did not change. Only the values did.

---

## Step 2: Compare the values of the two revisions

Read the values of the current revision, then the values of revision 1:

```sh
helm get values istiod -n istio-system
helm get values istiod -n istio-system --revision 1
```

```text
USER-SUPPLIED VALUES:
null

USER-SUPPLIED VALUES:
global:
  proxy:
    resources:
      requests:
        cpu: 10m
        memory: 64Mi
meshConfig:
  accessLogFile: /dev/stdout
  outboundTrafficPolicy:
    mode: ALLOW_ANY
pilot:
  autoscaleEnabled: false
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
```

Revision 2 has no user-supplied values at all, so it runs on the chart defaults. Revision 1 is the last good revision: it holds every setting from the install.

You could rebuild a values file from revision 1 and run a new `helm upgrade`. The end state would look the same, but the task asks for a rollback, and the grader checks that the latest revision is a rollback to revision 1.

---

## Step 3: Roll istiod back to revision 1

`helm rollback` applies the manifests of revision 1 again and records the result as a new revision, revision 3:

```sh
helm rollback istiod 1 -n istio-system --wait
```

```text
Rollback was a success! Happy Helming!
```

If your machine runs Helm 4, the rollback can stop with `Error: conflict occurred while applying object /istio-validator-istio-system`. Helm 4 applies objects with server-side apply, and `istiod` itself owns the `failurePolicy` field of its validating webhook, so Helm 4 must be told to take that field back. Run the same `helm rollback` command again with `--force-conflicts` added. Helm 3 does not need that flag.

Run `helm history istiod -n istio-system` again. You should see a new revision 3 with the status `deployed` and the description `Rollback to 1`. Revision 2 is now `superseded`. The history keeps the bad revision; it records what happened, not what you meant.

Do not roll back `istio-base` or `istio-ingressgateway`. `helm rollback` touches only the release you name, and those two releases never had a bad revision.

---

## Step 4: Check that the settings are live

Read the access log setting, the HorizontalPodAutoscalers, and the resource requests of `istiod`:

```sh
kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep accessLogFile
kubectl -n istio-system get hpa
kubectl -n istio-system get deploy istiod -o jsonpath='{.spec.template.spec.containers[0].resources.requests}{"\n"}'
```

```text
accessLogFile: /dev/stdout
No resources found in istio-system namespace.
{"cpu":"100m","memory":"256Mi"}
```

The rollback removed the HorizontalPodAutoscaler that revision 2 created, because revision 1 does not contain it. Access logging and the `istiod` requests are back.

---

## Step 5: Look at the running sidecar

The control plane is back, but the running pod was created while revision 2 was live. Read the resource requests of its `istio-proxy` container:

```sh
kubectl -n default get pod -l app=notification-service \
  -o jsonpath='{.items[0].spec.containers[?(@.name=="istio-proxy")].resources.requests}{"\n"}'
```

You should see the chart-default requests, not `10m` and `64Mi`. The injection webhook wrote those requests into the pod spec when the pod was created, and `helm rollback` never restarts pods.

---

## Step 6: Restart the workload

Restart the Deployment so the new pod passes through the injection webhook of the rolled-back `istiod`:

```sh
kubectl -n default rollout restart deployment notification-service
kubectl -n default rollout status deployment notification-service --timeout=180s
```

Then read the sidecar's requests again:

```sh
kubectl -n default get pod -l app=notification-service \
  -o jsonpath='{.items[0].spec.containers[?(@.name=="istio-proxy")].resources.requests}{"\n"}'
```

```text
{"cpu":"10m","memory":"64Mi"}
```

The new sidecar has the requests from revision 1. If the command still shows the old requests, the old pod was still terminating; run it again after a few seconds.

---

## Step 7: Submit

```sh
astrona submit
```

The grader checks that:

- The latest `istiod` revision is `deployed` and its description is `Rollback to 1`.
- `istio-base` and `istio-ingressgateway` are still at revision 1.
- `istiod` runs 1.29.8, is ready, requests `100m` CPU and `256Mi` memory, and has no HorizontalPodAutoscaler.
- The `istio` ConfigMap has `accessLogFile: /dev/stdout`.
- `default` holds one Deployment, and its running pod is `Ready` with an `istio-proxy` container that requests `10m` CPU and `64Mi` memory.

---

## Common mistakes

*   **Fixing forward with `helm upgrade` instead of rolling back.** A rebuilt values file gives the same settings, but the latest revision says `Upgrade complete`, not `Rollback to 1`, and the grader rejects it.
*   **Rolling back and stopping.** `helm rollback` restores the release's objects, not the pods created from them. The running sidecar keeps the chart-default requests until you restart the workload.
*   **Rolling back the other releases too.** `istio-base` and the gateway never had a bad revision. A rollback of one release is not a rollback of the install.
*   **Rolling back to the wrong revision.** `helm rollback istiod 2` re-applies the bad values. Read `helm history` first and pick the revision that holds the settings.
*   **Deleting and recreating the Deployment.** It gives a new pod, but the task says to leave the workload in place, and the grader counts Deployments.
