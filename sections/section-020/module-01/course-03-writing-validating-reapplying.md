# Writing, Validating And Re-applying The Document

An `IstioOperator` document is the blueprint you hand to `istioctl install`. It has four layers: `profile` picks a stock blueprint, `components` decides what is deployed and how big, `meshConfig` holds the mesh-wide standing orders, and `values` passes settings straight to the Helm charts.

This part is about the file itself. You write a complete document, meet the list rule that turns a typo into silence, check the file before it touches a cluster, and see what happens on the second install. Each habit here exists because of one specific way installs go wrong.

## A document that changes three layers

Start with a real document. It changes the `demo` profile in three different ways: no egress gateway, access logs to standard output, and a different CPU request for `istiod`.

Save this as `istio-custom.yaml` (it replaces any earlier file with the same name):

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: demo
  components:
    egressGateways:
      - name: istio-egressgateway
        enabled: false
    pilot:
      k8s:
        resources:
          requests:
            cpu: 100m
  meshConfig:
    accessLogFile: /dev/stdout
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
```

Do not apply it yet. Three layers means three different places the result will show up: a Deployment disappears, a field on a pod template changes, and two keys appear in the `istio` ConfigMap. Keep that map in mind, and the checks later become obvious.

## Lists are matched by `name`, and a typo creates a new entry

`components.egressGateways` and `components.ingressGateways` are **lists**, because a cluster can have several of each. Istio matches your entries against the profile's entries by the `name` field.

That is the cause of a nasty failure. Write `name: istio-egress-gateway`, with one extra hyphen, and Istio does not complain. It sees an entry whose name matches nothing in the profile, and treats it as a *new* gateway that happens to be turned off. The real `istio-egressgateway` is untouched and keeps running. Your file says `enabled: false`, the install succeeds, and the gateway is still there.

The general rule: **for any list under `components`, the `name` is the key that joins your entry to the profile's, and a name that matches nothing adds an entry instead of changing one.** There is no "no such component" error, because as far as the blueprint is concerned you did not make a mistake.

`components.pilot` is a single object, not a list. A misspelled `pilot` key is simply an unknown field, which is the second silent failure.

## Unknown fields, and the two commands that catch them

Misplaced or misspelled keys under `spec` are often accepted and ignored. A block indented one level too far becomes a child of the wrong parent. That makes it an unknown field rather than a syntax error, and an unknown field does not stop an install.

### Two free checks

Two commands catch both this and the list problem, and neither touches the cluster:

- **`istioctl validate -f <file>`** checks the document against the `IstioOperator` schema. It catches unknown fields and wrong types.
- **`istioctl manifest generate -f <file>`** renders your document into the Kubernetes objects it would apply. This is the stronger check, because it shows you the *result*. If your change is not in the rendered manifest, it did not take, whatever the reason. Older Istio used `istioctl profile dump -f` for this; that command was removed.

### See it in your playground

Validate the file, then count the egress and ingress gateway objects in the rendered result, and look for the outbound policy:

<!-- astrona:playground:renew -->

```sh
istioctl validate -f istio-custom.yaml
istioctl manifest generate -f istio-custom.yaml | grep -c '^  name: istio-egressgateway$'
istioctl manifest generate -f istio-custom.yaml | grep -c '^  name: istio-ingressgateway$'
istioctl manifest generate -f istio-custom.yaml | grep -A2 outboundTrafficPolicy
```

Expect something like:

```text
"istio-custom.yaml" is valid
0
2
  outboundTrafficPolicy:
    mode: REGISTRY_ONLY
```

Zero egress gateway objects and a surviving ingress gateway prove that your list entry matched the profile's entry. Now misspell the name on purpose and run the same commands. `validate` still passes, and the egress count is no longer zero, because your entry defined a *second*, disabled gateway and left the original running.

## A rendered manifest is a change review

`istioctl manifest generate` prints every object the install would create. Saving that output and comparing it with the last run is the closest thing installation settings have to a change review:

```sh
istioctl manifest generate -f istio-custom.yaml > proposed.yaml
grep -c '^kind:' proposed.yaml
```

On a cluster you care about, this is the step between "the file looks right" and "apply it". It costs seconds, and it is the only place where a surprising deletion shows up *before* it happens.

## Applying, and checking all three layers

Now build the solar system to match the blueprint. Apply it:

```sh
istioctl install -f istio-custom.yaml -y
```

Then check the result, one layer at a time:

```sh
kubectl -n istio-system get deploy
kubectl -n istio-system get deploy istiod -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}{"\n"}'
kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep -A2 -E 'accessLogFile|outboundTrafficPolicy'
```

Expect something like:

```text
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
istio-ingressgateway   1/1     1            1           14m
istiod                 1/1     1            1           14m

100m

accessLogFile: /dev/stdout
outboundTrafficPolicy:
  mode: REGISTRY_ONLY
```

The egress gateway is gone, `istiod` has the requested CPU, and both mesh keys are live. The ingress gateway is untouched: your document never mentioned it, and `demo` still turns it on. Leaving something out *inside* a profile you build on is not the same as leaving out the profile.

## Comparing an installation with its baseline

Once the installation is a file, "what have we changed about Istio?" has an exact answer. Render the stock profile and your document, and compare the two.

### See it in your playground

Comparing only object *names* keeps the answer to one screen:

```sh
diff <(istioctl manifest generate --set profile=demo   | grep '^  name: ' | sort -u) \
     <(istioctl manifest generate -f istio-custom.yaml | grep '^  name: ' | sort -u)
```

Expect something like:

```text
6,8d5
<   name: istio-egressgateway
<   name: istio-egressgateway-sds
<   name: istio-egressgateway-service-account
```

Three objects removed and nothing else: exactly the one component you turned off. Your other two changes are single fields (the CPU request and two `meshConfig` keys), so they do not show up when you compare names only. Drop `grep '^  name: '` from both sides to see them. If this comparison ever shows something you did not intend, you can fix it before it reaches a cluster.

## The second install reverts what you leave out

`istioctl install` does not add to what is already there. It makes the cluster match the document you pass, and takes away Istio objects and settings the document no longer describes.

Here is what that means field by field. Install `istio-custom.yaml`, then run `istioctl install --set profile=demo -y` with no file. The egress gateway comes back, access logging disappears, and the CPU request drops back to the profile's value. Nothing warns you: you asked for `demo`, and `demo` is what you got.

The rule follows directly: **one file per control plane, passed on every install, kept in version control.** `--set` is fine for a one-off test on a throwaway cluster. Anywhere else it is a liability, because the state it creates exists only in someone's shell history.

## Good habits for real clusters

These habits come straight from the failures above. Each one costs seconds.

**Validate, render, compare, apply, in that order.** The first three only read. They catch schema errors, list names that match nothing, and unexpected deletions, and none of them needs a cluster you are willing to break.

**Keep the file next to the cluster's other manifests.** A committed `IstioOperator` file is not about tidiness. Comparing rendered manifests needs a previous version to compare against.

**Mesh-wide means gateways too.** A `meshConfig` change applies to every proxy, ingress and egress gateways included. When a requirement is really for one workload, a `Telemetry` or `DestinationRule` resource is the right tool, and it needs no new install.

> [!TIP]
> Before any `istioctl install -f`, run `istioctl manifest generate -f` on the same file and look for the one change you expect. If you cannot find it in the rendered output, the install will not make it either.

## Common pitfalls

> [!WARNING]
> **Expecting an install to merge with the previous one.** It replaces instead, and anything you leave out reverts. This is behind most "who turned off our access logging?" incidents.
>
> **A wrong `name` in a component list.** Lists are matched by `name`; a name that matches nothing silently adds a second entry and leaves the original running. `istioctl manifest generate -f` shows the original still there.
>
> **Indentation errors under `components`.** Misplaced keys become unknown fields and are ignored. `istioctl validate -f` and `istioctl manifest generate -f` catch them; a successful install does not.
>
> **Editing the `istio` ConfigMap directly.** It works, `istiod` picks it up, and the next install reverts it. Change the document instead.
>
> **Using `spec.values` where a structured field exists.** Both may work today, but `values` passes straight into the charts and can change between versions. Prefer `components` and `meshConfig`.
>
> **Assuming a `meshConfig` change is instant everywhere.** `istiod` picks it up quickly, and proxies get it on the next push. A `STALE` that stays in `istioctl proxy-status` is the signal that something is wrong.
>
> **Mixing up the two kinds of sizing.** `components.pilot.k8s.resources` sizes one Deployment, `istiod`. `values.global.proxy.resources` sizes every injected sidecar, which is a very different bill.

## Your mission: Customize An Istio Installation

You can now write an `IstioOperator` file across several layers, check it before you apply it, and prove each change landed. Now prove it in a graded mission: change a stock `demo` installation in three layers at once, without breaking the workload that is already in the mesh.

The mission runs in its own training solar system, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-013-playground-020-01
```

Then start the mission:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-020/module-01/labs/lab-01
```

Read the task in [`question.md`](./labs/lab-01/question.md) and solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

When the mission is done, remove it and wake your playground up again:

```sh
astrona destroy ats-013-lab-020-01
astrona start ats-013-playground-020-01
```
