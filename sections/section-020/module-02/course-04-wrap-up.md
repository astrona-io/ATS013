# Wrap-Up: Mission Debrief

Well flown, astronaut. You have finished every part and the mission in this module. Before you move on, look back at what you learned, check yourself, and land the playground cleanly.

## What you learned

This module was about how a ship gets its communications officer: sidecar injection, which labels decide it, and what it adds to the pod.

**From [Injection As Admission Control](./course-01-injection-as-admission-control.md):**

- Injection is a mutating admission webhook. The API server calls `istiod` for Pods, on `CREATE` only.
- The decision is made once, when the pod is created. Labelling a namespace changes nothing until the pods are recreated, for example with `kubectl rollout restart`.
- The `istio-sidecar-injector` configuration has two entries: one fires on the namespace label, the other on a pod label `sidecar.istio.io/inject: "true"` in a namespace that has not opted in.
- Istio sets `failurePolicy: Fail`, so if `istiod` cannot be reached, new pods in injected namespaces are refused.

**From [The Precedence Rules](./course-02-the-precedence-rules.md):**

- The pod template label beats the namespace in both directions: `"false"` pulls a workload out, `"true"` pushes one in.
- The label must be on `spec.template.metadata.labels`. On the Deployment's own `metadata.labels` it applies cleanly and does nothing.
- Label values are strings, so `"true"` and `"false"` need quotes.
- On one namespace, `istio-injection` beats `istio.io/rev` silently.

**From [What Injection Writes Into The Pod](./course-03-what-injection-writes.md):**

- Injection adds the `istio-proxy` container, the `istio-init` container, volumes, environment variables and annotations.
- `istio-init` writes `iptables` rules that send outbound traffic to port `15001` and inbound traffic to port `15006`; Envoy's own user ID `1337` is left out.
- `istioctl kube-inject -f` shows the injected manifest without applying it.
- `traffic.sidecar.istio.io/*` annotations exclude traffic from capture, and that traffic gets no mesh features. With the Istio CNI plugin, `istio-init` is replaced or left out.

## Your missions

You proved the skill in a graded mission, right after the part that taught it:

| Mission | After the part | What you proved |
| --- | --- | --- |
| [Control Sidecar Injection](./labs/lab-01/question.md) | The Precedence Rules | opt a namespace in, pull one workload out and force one in, with every label on the pod template |

If you skipped it, go back to it now.

## Check yourself

Try to answer each question before you open the answer.

<details>
<summary>1. You label a namespace with <code>istio-injection=enabled</code>. Its pods still have one container. Why?</summary>

Injection happens only when a pod is created. Those pods were admitted before the label existed. Recreate them, for example with `kubectl rollout restart deployment`, and the new pods get the sidecar.
</details>

<details>
<summary>2. The webhook is registered for which resource and which operation?</summary>

For `pods`, on `CREATE`. It never sees the Deployment, and it never runs again for a pod that already exists.
</details>

<details>
<summary>3. You put <code>sidecar.istio.io/inject: "false"</code> on a Deployment's <code>metadata.labels</code> and restart it. The pod still gets a sidecar. Why?</summary>

The webhook's `objectSelector` is checked against the pod. A label on the Deployment's own metadata is never copied to the pod. Move it to `spec.template.metadata.labels`.
</details>

<details>
<summary>4. A namespace has no injection label. One Deployment's pod template has <code>sidecar.istio.io/inject: "true"</code>. Does its pod get a sidecar?</summary>

Yes. The second webhook entry, `object.sidecar-injector.istio.io`, fires when the namespace has not opted in but the pod has.
</details>

<details>
<summary>5. A namespace carries both <code>istio-injection=enabled</code> and <code>istio.io/rev=canary</code>. Which control plane do its new pods use?</summary>

The default one. `istio-injection` wins silently and the revision label is ignored. Remove `istio-injection` to move the namespace to the revision.
</details>

<details>
<summary>6. Which ports do the injected traffic rules send outbound and inbound traffic to?</summary>

Outbound traffic goes to `15001`, inbound traffic to `15006`. You can see them as `-p 15001` and `-z 15006` in the `istio-init` arguments.
</details>

<details>
<summary>7. You inspect an injected pod and find no <code>istio-init</code> container. Is injection broken?</summary>

Not necessarily. On a cluster with the Istio CNI plugin, the node sets up the traffic rules, and `istio-init` is replaced by `istio-validation` or left out. Look for `istio-proxy` instead.
</details>

<details>
<summary>8. What is the risk of <code>traffic.sidecar.istio.io/excludeOutboundPorts</code>?</summary>

Traffic on those ports skips the proxy, so it gets no mTLS, no authorization policy and no telemetry, while the workload still looks meshed. Use it only for a documented reason.
</details>

## Clean up the playground

Your playground is a whole Kubernetes cluster running on your machine. When you are done with this module, remove it, and the mission if it is still running.

First, see what is still running:

```sh
astrona list
```

Remove the playground. The command takes its **name**, not its folder path:

```sh
astrona destroy ats-013-playground-020-02
```

If `astrona list` also showed the mission, remove it the same way:

```sh
astrona destroy ats-013-lab-020-02
```

Then check that everything is gone:

```sh
astrona list
```

```text
No astrona labs running.
```

You can start the playground again at any time with the `astrona run` command from the module's landing page. It always starts clean, so nothing you broke carries over.
