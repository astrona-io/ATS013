# Part 3 — Writing, Validating And Re-applying The Document

> Prerequisite: [Part 2 — meshConfig: From File To ConfigMap To Proxy](./course-02-meshconfig-from-file-to-proxy.md). Next: [the module landing page](./course.md), then [Module 2 — Control Sidecar Injection](../module-02/course.md).

Parts 1 and 2 covered which layer a setting belongs in and how a mesh-wide setting travels. This part is about the file itself: writing a complete document, the list-matching rule that turns a typo into silence, checking it before it touches a cluster, and what happens on the second install. Everything here is a habit rather than a concept, and each habit exists because of a specific way installs go wrong.

## A document that changes three layers

Build one that deviates from `demo` in three distinct ways — no egress gateway, access logs to standard output, and a larger CPU request for `istiod`:

```sh
cat > istio-custom.yaml <<'YAML'
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
YAML
```

Three layers, three different places the result will show up: a Deployment disappears, a field on a pod template changes, and two keys appear in the `istio` ConfigMap. Keeping that mapping in mind is what makes the verification step obvious rather than something you look up.

## Lists are matched by `name`, and a typo creates a new entry

`components.egressGateways` and `components.ingressGateways` are **lists**, because a cluster can have several of each. Entries are matched against the profile's entries by the `name` field.

That is the mechanism behind a specific, nasty failure. If you write `name: istio-egress-gateway` — one extra hyphen — Istio does not error. It sees a list entry whose name matches nothing in the profile, and treats it as a *new* gateway definition that happens to be disabled. The original `istio-egressgateway` is untouched and keeps running. Your file says `enabled: false`, the install succeeds, and the gateway is still there.

The general rule: **for any list under `components`, the `name` is the join key, and an unmatched name adds rather than modifies.** There is no "no such component" error because, from the API's point of view, you did not make one.

The same shape appears with `components.pilot`, but it is a single object rather than a list, so a misspelled `pilot` key is simply an unknown field — which brings us to the second silent failure.

## Unknown fields, and the two commands that catch them

Misplaced or misspelled keys under `spec` are frequently accepted and ignored. A block indented one level too far becomes a child of the wrong parent, which makes it an unknown field rather than a syntax error, and an unknown field does not stop an install.

Two checks catch both this and the list-matching problem, and both are free:

- **`istioctl validate -f <file>`** checks the document against the `IstioOperator` schema. It catches unknown fields and type errors.
- **`istioctl manifest generate -f <file>`** renders your document into the Kubernetes objects it would apply, without touching the cluster. This is the stronger check, because it shows you the *result* — if your override is not visible in the rendered manifest, it did not take, whatever the reason. (On older Istio this role belonged to `istioctl profile dump -f`; that command family was removed.)

> [!TIP]
> **Try it — prove your override actually landed in the rendered document**
>
> ```sh
> istioctl validate -f istio-custom.yaml
> istioctl manifest generate -f istio-custom.yaml | grep -c '^  name: istio-egressgateway$'
> istioctl manifest generate -f istio-custom.yaml | grep -c '^  name: istio-ingressgateway$'
> istioctl manifest generate -f istio-custom.yaml | grep -A2 outboundTrafficPolicy
> ```
>
> Expect something like:
>
> ```text
> "istio-custom.yaml" is valid
> 0
> 2
>   outboundTrafficPolicy:
>     mode: REGISTRY_ONLY
> ```
>
> Zero egress gateway objects and a surviving ingress gateway confirms your list entry matched the profile's entry. Try the same commands after deliberately misspelling the name — `validate` still passes, and the egress count comes back non-zero, because your entry defined a *second*, disabled gateway and left the original running. That contrast is the clearest possible demonstration of the rule.

## A rendered manifest is a change review

`istioctl manifest generate` prints every Kubernetes object the install would create, without touching the cluster. Diffing that output against the previous run is the closest thing install-time configuration has to a change review:

```sh
istioctl manifest generate -f istio-custom.yaml > proposed.yaml
grep -c '^kind:' proposed.yaml
```

On a cluster you care about, this is the step between "the file looks right" and "apply it". It costs seconds and it is the only place a surprising deletion shows up *before* it happens.

## Applying, and verifying across all three layers

```sh
istioctl install -f istio-custom.yaml -y
```

> [!TIP]
> **Try it — confirm each layer independently**
>
> ```sh
> kubectl -n istio-system get deploy
> kubectl -n istio-system get deploy istiod -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}{"\n"}'
> kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep -A2 -E 'accessLogFile|outboundTrafficPolicy'
> ```
>
> Expect something like:
>
> ```text
> NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
> istio-ingressgateway   1/1     1            1           14m
> istiod                 1/1     1            1           14m
>
> 100m
>
> accessLogFile: /dev/stdout
> outboundTrafficPolicy:
>   mode: REGISTRY_ONLY
> ```
>
> The egress gateway is gone, `istiod` has the requested CPU, and both mesh keys are live. The ingress gateway is untouched, because your document never mentioned it and `demo` still enables it — a useful reminder that omitting something inside a profile you inherit is not the same as omitting the profile.

## Diffing an installation against its baseline

Once the install is a file, "what have we changed about Istio?" has an exact answer: render the baseline profile and your document, and diff the two manifests. Comparing object *names* keeps the answer to one screen; drop the `grep` to compare every field.

> [!TIP]
> **Try it — your deviations, and nothing else**
>
> ```sh
> diff <(istioctl manifest generate --set profile=demo   | grep '^  name: ' | sort -u) \
>      <(istioctl manifest generate -f istio-custom.yaml | grep '^  name: ' | sort -u)
> ```
>
> Expect something like:
>
> ```text
> 6,8d5
> <   name: istio-egressgateway
> <   name: istio-egressgateway-sds
> <   name: istio-egressgateway-service-account
> ```
>
> Three objects removed and nothing else — exactly the one component you disabled. Your other two changes are field-level (`istiod`'s CPU request and two `meshConfig` keys), so they do not appear in a name-only diff; drop the `grep '^  name: '` from both sides to see them. If this diff ever shows something you did not intend, that is drift you can fix before it reaches a cluster.

## The second install reverts what you omit

`istioctl install` reconciles the cluster to the document you pass — [Part 4 of the section 010 istioctl module](../../section-010/module-01/course-04-reconciliation-and-removal.md) covers the mechanism, including the ownership labels that decide what gets pruned. Here is the field-level consequence.

Install `istio-custom.yaml`, then install `--set profile=demo` with no file. The egress gateway returns, the access logging disappears, and the CPU request drops back to the profile's value. Nothing warns you: you asked for `demo`, and `demo` is what you got.

The rule follows directly: **one file per control plane, passed on every install, kept in version control.** `--set` is fine for a one-off experiment on a throwaway cluster and a liability anywhere else, because the state it produces exists only in a shell history.

> [!WARNING]
## Common pitfalls

> [!WARNING]
> **Expecting an install to merge with the previous one.** It reconciles instead — anything you omit reverts. This is behind most "who turned off our access logging?" incidents.
>
> **A wrong `name` in a component list.** Lists are matched by `name`; an unmatched name silently adds a second entry and leaves the original running. `istioctl manifest generate -f` shows the original still there.
>
> **Indentation errors under `components`.** Misplaced keys become unknown fields and are ignored. `istioctl validate -f` and `manifest generate -f` catch them; a successful install does not.
>
> **Editing the `istio` ConfigMap directly.** It works, `istiod` picks it up, and the next install reverts it. Change the document instead.
>
> **Using `spec.values` where a structured field exists.** Both may work today; `values` is a chart-internals passthrough with weaker guarantees. Prefer `components` and `meshConfig`.
>
> **Assuming a `meshConfig` change is instant everywhere.** `istiod` picks it up quickly, proxies get it on the next push. Persistent `STALE` in `proxy-status` is the signal that something is wrong.
>
> **Sizing confusion.** `components.pilot.k8s.resources` sizes one Deployment. `values.global.proxy.resources` sizes every injected sidecar, which is a very different bill.

## Operational considerations

**Validate, render, diff, apply — in that order.** The first three are read-only and take seconds between them. They catch schema errors, unmatched list names and unexpected deletions respectively, and none of them requires a cluster you are willing to break.

**Keep the file where the cluster's other manifests live.** The value of a committed `IstioOperator` is not tidiness; it is that diffing rendered manifests needs a previous version to compare against.

**Mesh-wide means gateways too.** A `meshConfig` change applies to every proxy, including ingress and egress gateways. When a requirement is genuinely per-workload, a `Telemetry` or `DestinationRule` resource at runtime is the correct tool and does not require reinstalling anything.

> *An unmatched list `name` adds instead of modifies, an unknown field is ignored rather than rejected, and a second install reverts what you left out — validate and render before you apply, because none of those three fail loudly.*

## Reference

- [Customizing the configuration](https://istio.io/v1.30/docs/setup/additional-setup/customize-installation/) — the `-f` workflow and override examples.
- [IstioOperator API](https://istio.io/v1.30/docs/reference/config/istio.operator.v1alpha1/) — the schema `istioctl validate` checks against.
- [istioctl manifest generate](https://istio.io/v1.30/docs/reference/commands/istioctl/#istioctl-manifest-generate) — rendering a profile or a file without applying it.
- `istioctl install --help` — confirm `--dry-run` and the overlay flags on the version you have. Note `-o` was removed; use `manifest generate` to capture the YAML.
