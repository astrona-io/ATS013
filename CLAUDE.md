# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Technical documentation in plain English

This is technical documentation. Say exactly what the system does, with the
real technical terms, in clear and simple English. Never hide a concept
behind a metaphor, a made-up name or a vague word: the reader must learn the
words they will meet in the product, the logs and the exam.

Strict guidelines:

1. Use the correct technical term every time (request, response, pod,
   namespace, Service, sidecar proxy, certificate, mTLS, JWT, listener). The
   first time a term appears in a file, define it in one plain sentence that
   says what it is and what it does. Spell out every acronym on first use.
2. No metaphors or analogies in explanations. Not "the communications
   officer", but "the sidecar proxy (Envoy)"; not "a signal", but "a
   request"; not "the planet", but "the namespace".
3. Simple sentences. Target a Flesch-Kincaid Grade Level of 8 or 9 for the
   prose around the terms. Keep sentences direct; split long sentences into
   two. No corporate buzzwords.
4. Use short paragraphs (max 3-4 sentences per paragraph).
5. Use the active voice ("istiod sends the configuration", not "the
   configuration is sent").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page, a few
  deep-dive parts and a summary page. The landing page is a map: goals, what
  to know first, the order of the parts. The real teaching goes in the parts.
  The summary closes the module. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, renumber the files, fix every "Part N"
  reference in the module and `astrona.yaml`.
- **Read like a book, not like a web page.** Each part reads as a chapter of
  a technical book. Open with a short paragraph on the problem it solves and
  why it matters. Link each paragraph to the next with a transition sentence.
  Close with a paragraph that sums up what the reader now knows and the
  question still open, before `## Common pitfalls` and the mission. Write
  explanations as prose; keep bullets for real lists (fields, ordered steps,
  options). Use `##` only when the topic changes and `###` only inside a long
  section, never for a single command. Weave hands-on steps into the text:
  one or two sentences on what to run and why, the command, the real output,
  then a sentence or two on what it shows.
- **The module ends with a summary.** The last page of every module is
  `course-0N-summary.md` with the title `# Summary`: a few short prose
  paragraphs on what the reader learned, organised by idea, optionally with
  one short list of key facts. It names no parts, modules, sections or
  chapters, and has no links, lab table, quiz or commands. Its last line is
  `<!-- astrona:playground:destroy -->` on its own line; the platform turns it
  into the step that removes the playground.
- **Every heading gets an intro.** A `##` section that has `###`
  subsections starts with one to three sentences that say what the section
  is about and why it matters, before the first `###`. Never put a `###`
  directly under a `##`.
- **Every module stands on its own.** Never refer to other sections or
  modules: no "see section 040", "as module 3 showed", "you met this in
  section 000", and no links to pages in another module. If the reader needs
  a fact from elsewhere, state the fact directly in one or two sentences.
  This also goes for parts of the same module: never write "Part 2 shows",
  "from Part 1" or "as in Part 3". Say the fact itself ("the commands below
  need the `scout` `DestinationRule` applied"). This includes the summary.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Use them as they are and
  define each one in plain technical words the first time it appears in a
  file. Spell out acronyms on first use, with a short plain meaning.
- **The space theme is only for examples.** Space appears in two places and
  nowhere else: the names of the example workloads (the Starfleet: `bridge`,
  `scout`, `shuttle`, `probe`, the `starfleet` and `outpost` namespaces) and
  the short scenario that opens a lab task or a practice exercise (for
  example "the `drifter` in `outpost` must keep reaching the probe"). The
  explanation around an example is plain technical text: write "the
  `shuttle` pod sends a request to the `probe` Service", never "the shuttle
  sends a signal to the probe ship". Do not address the reader as an
  astronaut, and do not use space metaphors (communications officer, mission
  control, badge, airlock, guest list, star chart) for Istio or Kubernetes
  concepts. Titles of pages and labs name the technical task ("Require mTLS
  With PeerAuthentication"), not a space story.
- **Show one real example before the rule.** Start with a concrete case the
  reader can run, then give the general rule.
- **Say which part does the work.** Readers often mix up the parts of a system
  that sit close together. Whenever something happens, say which component
  did it.
- **Never change code to fit the style.** Commands, configuration files, field
  names, resource names, log lines and command output stay exactly as they
  are. They were run and checked on a real system. Never make up command
  output. If you shorten it, say that you did.
- **Prose only.** The grade-level and sentence rules apply to explanations.
  They do not apply to code blocks, tables of field names or reference lists
  (those may stay short and dense).
- **Keep the page furniture the same.** Hands-on steps are part of the prose
  (see "Read like a book"), not boxes or headings of their own. A `> [!TIP]` box is
  only for a real tip: advice the reader can reuse beyond this one step (a
  habit, a shortcut, how to spot a problem, an exam habit). Everything else
  is a normal sentence: notes about the current step ("if the log line is
  old, run it again"), background facts, optional extra steps, and plain
  information. Never a command snippet, never two in a row, and most pages
  need zero or one tip. Each part ends with a
  `## Common pitfalls` `> [!WARNING]` block for that part only. Use a Mermaid
  diagram for a flow, an order or a state change, keep it under about 12
  boxes, and follow it with one sentence that says what it shows.
- **Labs come right after the part they practise.** Do not collect all
  graded labs at the end of a module. In `astrona.yaml`, put each lab (its
  `question.md` reading and the `lab` entry) right after the reading part it
  tests. If a part teaches a gradeable skill and no lab covers it, create a
  new lab. That part then ends with a `## Your mission: <lab title>` section:
  one sentence on what the reader can now do, one on what the mission asks,
  then pause the playground (`astrona stop <playground name>`), the
  `astrona run` and `astrona submit` commands, and finally
  `astrona destroy <lab name>` plus `astrona start <playground name>`.
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), summary pages (they carry
  `<!-- astrona:playground:destroy -->`) or pages without commands.
- **Mermaid without HTML.** The platform renders Mermaid with HTML labels
  switched off, so `<br/>` and any other HTML tag break the drawing. Rules:
  - One line per box, no `<br/>`, no HTML. Keep the box to the thing's name
    (`"scout-v2"`, `"istiod"`, `"Service: scout"`).
  - Put the logic on the arrows: `E -->|"version: v2"| P2`,
    `I -->|"CDS"| C`, `A -->|"end-user: jason"| B`. Keep edge labels short.
  - Quote every label. Prefer `flowchart TB`; use `LR` only for a short chain.
  - Sequence diagrams: short participant aliases (`participant S as shuttle`)
    and short message text.
  - Anything longer (cluster names, full hostnames) goes in the sentence under
    the diagram.
- **Every course starts with an Introduction.** It lives in `sections/intro/`
  and is the first entry in `astrona.yaml` (`id: module-intro`, title
  "Introduction"). It has exactly these four pages, in this order:
  - `README.md`, `# Introduction`: what the introduction covers and its three
    pages, named in prose (no links), ending with the topic the course starts
    with.
  - `course-01-welcome.md`, `# Welcome To The Course`: who the course is for,
    the exam domain and what the reader can do at the end, the words the
    course uses, the example app, how the course is laid out and how to read
    a page.
  - `course-02-get-your-machine-ready.md`, `# Get Your Machine Ready`: the
    tools to install, the `astrona` commands used every day, and what to do
    when a start goes wrong.
  - `course-03-how-this-course-is-made.md`, `# How This Course Is Made`: how
    content is written and checked, the maintainers, how to report a mistake,
    and the license.
  The Introduction teaches no product content and has no playground, labs or
  summary. Its only links are the repository's contributors page, issues
  page and license.
- **No links to other course files.** A course page (every reading listed in
  `astrona.yaml`, the playground guide `docs/overview.md`, and a lab's
  `question.md` and `solution.md`) never links to or points the reader at
  another page or file of the repository: no links to parts, summaries,
  labs, `question.md`, other modules, sections or the Introduction, and no
  "see `practice.md`" or "open `config.yaml`". The platform shows the pages in
  the order of `astrona.yaml`, so a link only adds a second, often wrong,
  path. Name a thing in plain words when the reader needs it ("the task is on
  the next page"), and state a fact on the page itself instead of sending the
  reader somewhere else. Repository files for authors (the root `README.md`,
  a lab's or playground's `README.md`) may link.
- **No links to outside sources.** Course pages, labs and playground docs do
  not link to or point at outside websites (the one exception is the
  `resources` field of a lab entry in `astrona.yaml`) (official docs, GitHub, blogs,
  RFCs), and they have no "Reference" or "Official docs" lists. Everything the
  reader needs is explained on the page itself. Not affected: addresses the
  reader actually uses in a command or browser (`http://127.0.0.1:9080`,
  `curl https://httpbin.org`), and the Introduction's contributors and
  "report a mistake" links.
- **Configuration goes to a file first.** Whenever the reader should apply
  YAML (course parts, playground docs, labs), use three separate steps:
  1. "Save this as `virtualservice-scout.yaml`:" followed by a plain
     ` ```yaml ` block with only the YAML. No `cat > file <<'EOF'`, no
     `kubectl apply -f - <<EOF`, no shell around it.
  2. "Apply it:" followed by a ` ```sh ` block with only
     `kubectl apply -f virtualservice-scout.yaml`.
  3. "Then check the result:" followed by the check commands, if any.
  The file name says the kind and the object. If a value must come from the
  reader's cluster (an IP address), use a placeholder like `<PARTNER>` in the
  YAML and say how to get the value (`echo $PARTNER`); never put shell
  variables inside YAML. Apply an object the first time its YAML appears; do
  not show it once "to read" and paste it again later. Never tell the reader
  to apply something from the playground's `examples/` folder: they start the
  playground with `astrona run`, so that folder is not on their machine.
- **Helpers have readable names.** Shell helper functions and variables use
  names that say what they do (`check_route`, `count_versions`,
  `$SERVICE_URL`), never single letters.

## About this repo (ATS013 only)

Everything above is general and can be copied to other course repositories. This
section is only true for this one. It adds facts about this course; it never
changes a general rule. If anything here seems to disagree with the rules
above, the rules above win.

### What the student is trying to learn

- **The goal:** pass the **Installation, Upgrade And Configuration** domain
  of the **Istio Certified Associate (ICA)** exam. It is 20% of the exam, and
  every other domain builds on it.
- **What the exam really tests:** installing, configuring and upgrading Istio
  by hand, on a live cluster, under time pressure, and proving it worked. So
  the student must *do* things (install with `istioctl` and with Helm, change
  mesh settings, choose which pods get a sidecar, move workloads to a new
  control plane, switch on ambient mode), not just recognise words. Every
  explanation should lead to a command they can run, and every change should
  be proved with a command that shows the new state (`istioctl version`,
  `istioctl proxy-status`, `helm list`, a pod's container count, a request
  from `tester`).
- **The four exam topics (curriculum items):** installing Istio with
  `istioctl` or Helm, customizing the Istio installation, upgrading Istio
  (canary and in-place), and installing Istio in sidecar or ambient mode.
  Each section covers exactly one of them.
- **The sections:**

  | Section | Title | Curriculum item |
  | --- | --- | --- |
  | 010 | Installing Istio With istioctl Or Helm | Installing Istio with istioctl or Helm |
  | 020 | Customizing Your Istio Installation | Customizing your Istio installation |
  | 030 | Upgrading Istio (Canary, In-Place) | Upgrading Istio (canary, in-place) |
  | 040 | Installing Istio In Sidecar Or Ambient Mode | Installing Istio in sidecar or ambient mode |

- **The version:** everything is built and checked on **Istio 1.30.5** on a
  single-node `kind` cluster. The upgrade section (030) starts on **1.29.8**
  and moves to **1.30.5**, so the learner sees version skew happen. Do not
  teach fields, flags or output from other versions without saying so. There
  is no in-cluster Istio operator in these versions: `istioctl install`
  renders the manifests and applies them from the learner's machine.
- **The main sources:** the Istio install pages,
  <https://istio.io/latest/docs/setup/install/>, the upgrade pages,
  <https://istio.io/latest/docs/setup/upgrade/>, and the ambient install
  pages. Check every page against them.

### Terms, not metaphors

Explanations use Istio's, Envoy's, Helm's and Kubernetes' own words. Older
pages and the earlier version of this file used a space picture for each term
("mission control", "communications officer", "blueprint", "relay tower").
Do not use them. Replace them with the real terms when you touch a page.
Define each term in plain technical language on first use in a file, for
example:

| Term | First-use definition (example wording) |
| --- | --- |
| Sidecar proxy (Envoy) | A proxy container Istio adds to each pod; all inbound and outbound traffic of the pod passes through it |
| `istiod` | Istio's control plane; it turns Istio resources and mesh settings into proxy configuration and sends it, plus certificates, to every proxy |
| xDS | The protocol `istiod` uses to push configuration to running proxies, without a pod restart |
| Custom Resource Definition (CRD) | Adds a new kind of object (for example `VirtualService`) to the Kubernetes API server |
| Sidecar injection | The mutating admission webhook (`istio-sidecar-injector`) adds the `istio-proxy` container when a pod is created in a namespace or pod that opts in; running pods do not change |
| `istio-injection=enabled` / `sidecar.istio.io/inject` | The namespace label that turns injection on, and the pod label that overrides it for one pod |
| Native sidecar | The proxy runs as an init container with `restartPolicy: Always`, so it starts before the app container and stops after it |
| `istioctl install` | Renders the full set of Kubernetes manifests on the learner's machine from a profile plus overlays, then applies them and removes objects the new render no longer contains |
| `IstioOperator` | The input document for `istioctl install`; it is read once and is not a running controller |
| Profile | A built-in starting configuration (`default`, `demo`, `minimal`, `ambient`) |
| Overlay (`-f`, `--set`) | Settings layered on top of the profile; a `--set` flag wins over a file |
| `meshConfig` | Mesh-wide settings (access logging, outbound traffic policy); `istiod` reads them from the `istio` ConfigMap in `istio-system` |
| Helm chart / release | A chart is a package of templates; a release is one installed copy of a chart, with a name and a numbered history stored in a Secret |
| `istio/base`, `istio/istiod`, `istio/gateway` | The Helm charts for the CRDs, the control plane and a gateway; `base` goes first because the others need its CRDs |
| Version skew | The client (`istioctl`), the control plane and the proxies run different versions |
| Revision | A named control plane (`--set revision=...`, Deployment `istiod-<revision>`), so two can run side by side |
| `istio.io/rev` label | Picks which revision injects the pods of a namespace |
| Revision tag | A stable name (for example `prod`) that points at one revision; moving the tag moves the namespaces at their next pod restart |
| Canary / in-place upgrade | Install a new revision next to the old one and move namespaces over / replace the control plane in the same place |
| Ambient mode | A data plane mode without sidecars: a per-node proxy handles L4 traffic and an optional waypoint handles L7 |
| ztunnel | The per-node proxy in ambient mode; it does mTLS (mutual TLS) and L4 policy but cannot read HTTP |
| `istio-cni` node agent | Redirects the traffic of ambient pods to the ztunnel on their node |
| HBONE | The mTLS tunnel (HTTP-Based Overlay Network Environment) that ztunnels and waypoints use between them |
| Waypoint | An Envoy proxy, deployed as a Gateway API `Gateway`, that applies L7 rules (path, method, headers) for a namespace or Service |

### The example workloads

This course is about the mesh itself, not about an application, so its
workloads are small plain-named services. Use their names as they are in
commands, YAML and output, and describe them in technical terms. The
Starfleet app from the general rules (`bridge`, `scout`, `shuttle`, `probe`)
is not deployed in this repository; do not refer to it in a page until a
playground actually runs it.

| Kubernetes name | Image | What it is | Where |
| --- | --- | --- | --- |
| `notification-service` (Deployment and Service, port `80`) | `nginx:1.27-alpine` | Backend that answers every request; the main workload in most modules | Most playgrounds and labs; the Deployment is `notification-service-v1` in the upgrade and ambient playgrounds |
| `tester` | `curlimages/curl:8.11.1` | Client pod; test requests are sent from here with `kubectl exec deploy/tester -- curl ...` | Playground 030-03, the ambient playgrounds, some labs |
| `logging-agent`, `batch-job` | `busybox:1.36` | Pods with no network role, used to show injection choices | `inject-demo` (section 020, module 2) |
| `checkout-api`, `batch-runner`, `audit-shipper`, `nightly-report`, `order-api` | `nginx` / `busybox` / `curl` | Capstone workloads | `payments`, `legacy`, `orders` namespaces |
| `catalog-api`, `storefront` | `nginx` / `curl` | Ambient capstone workloads | `ambient-shop` (section 040 capstone) |
| `reporting-service` (Deployment and Service) | `nginx:1.27-alpine` | Second backend that stays on layer 4 while `notification-service` uses a service waypoint | `ambient-l7` (section 040, module 2, lab 2) |

Namespaces are named after the module: `mesh-demo`, `inject-demo`,
`canary-demo`, `inplace-demo`, `ambient-demo`, `ambient-l7`, plus
`istio-system` (control plane) and `istio-ingress` (the gateway in the Helm
installs). The section 030 module 1 playground runs `notification-service`
in `default`.

### Environment facts the text must respect

- **Where Istio comes from.** Every playground and lab downloads Istio with
  `curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION=... sh -` and
  copies `istioctl` to `/usr/local/bin`, or to `$HOME/.local/bin` when that
  is not writable. If `istioctl` is "not found", the fix is
  `export PATH="$HOME/.local/bin:$PATH"`.
- **Starting states differ per module, on purpose.** Never "fix" them in the
  bootstrap.
  - 010 module 1: no Istio at all (no `istio-system`, no CRDs, no webhooks).
  - 010 module 2: no Istio; `helm` 3 is installed and the `istio` chart
    repository (`https://istio-release.storage.googleapis.com/charts`) is
    added.
  - 020 module 1: Istio installed with `istioctl install --set profile=demo -y`.
  - 020 module 2: `--set profile=default`, and `inject-demo` has **no**
    injection label.
  - 030 module 1: Istio **1.29.8** installed with Helm (`istio-base`,
    `istiod`, `istio-ingressgateway` in `istio-ingress`) from a non-default
    values file.
  - 030 modules 2 and 3: Istio **1.29.8** installed with `istioctl`, and two
    binaries: plain `istioctl` is 1.29.8, and the target is only reachable as
    `istioctl-1.30.5`, so nobody upgrades by accident.
  - 040 module 1: `--set profile=ambient`, and `ambient-demo` is **not**
    enrolled yet.
  - 040 module 2: ambient profile, Gateway API CRDs `v1.5.1`, and
    `ambient-l7` already enrolled, with no waypoint.
- **No load balancer on `kind`.** A gateway Service's `EXTERNAL-IP` stays
  `<pending>`; the capstones ask for a `NodePort` gateway instead.
- **Ambient has no sidecars.** In section 040, never use `-c istio-proxy` or
  `istioctl proxy-config` on an application pod; use
  `istioctl ztunnel-config` and the waypoint's own proxy.
- **A waypoint is a Gateway API `Gateway`.** Without the Gateway API CRDs,
  `istioctl waypoint apply` fails with an unknown-kind error.
- **How install files are applied.** The general "Configuration goes to a
  file first" rule holds here too; only the apply step changes. For an
  `IstioOperator` file it is `istioctl install -f <file> -y`; for a Helm
  values file it is `helm install` or `helm upgrade` with `-f <file>`.
- **One owner per cluster.** A cluster is installed with `istioctl` or with
  Helm, never both. Pages must not mix the two on one cluster.

### Where things are in this repo

The tree was written before the general rules above. It has no
`sections/intro/` yet, and each module closes with a `course-0N-wrap-up.md`
page instead of `course-0N-summary.md`. Follow the general rules when you
add or rework those pages.

| What | Where |
| --- | --- |
| Course outline the platform reads: every reading page and lab, in order. Never list `solution.md` here | `astrona.yaml` |
| Overview, sections table, how to run things | `README.md` |
| Section overview and its modules | `sections/section-0N0/README.md` |
| Module reading: landing page, deep-dive parts, closing page | `sections/section-0N0/module-0M/course.md`, `course-0N-*.md` |
| Graded lab: task, walkthrough, setup, grader | `.../labs/lab-0N/` (`question.md`, `solution.md`, `bootstrap/`, `solution/apply.sh`, `validation/`) |
| Ungraded sandbox for a module | `.../playground/` (`config.yaml`, `bootstrap/prepare.sh`, `docs/overview.md`, which is the only learner page) |
| One graded integration lab per section | `sections/section-0N0/capstone/labs/lab-01/` |
| Section knowledge check (multiple choice) | `sections/section-0N0/quiz.md` |
| Closed-book simulation of the whole domain | `sections/final-domain-quiz.md` |
| Leftover copies of files the pages tell the learner to create (nothing reads them from here) | `istio-custom.yaml`, `istiod-values.yaml`, `catalog-*.yaml`, `notification-header.yaml` |

A lab folder holds:

| Path | Purpose |
| --- | --- |
| `config.yaml` | Lab definition; `metadata.docs` has `question: "question.md"` and `solution: "solution.md"` |
| `README.md` | Short intro for authors with `estimated_duration` front matter and the run, submit and destroy commands |
| `question.md` | The exam-style task. Starts with `# Question` and `Solve this question on: \`terminal\`` |
| `solution.md` | Step-by-step walkthrough with real output |
| `bootstrap/01-*.sh`, `bootstrap/02-*.sh` | Tooling, the Istio install where the task needs it, and the starting workloads; never the graded end state |
| `solution/apply.sh` | Reference end state, applied only by `astrona test` |
| `validation/validate-completed.sh` | Grading against the live cluster |

### Lab metadata in `astrona.yaml`

`astrona.yaml` has a `training:` block (id `ATS013`, domain
`Installation, Upgrade And Configuration`, weight `20`), one entry per
section under `modules:` (`module-010` to `module-040`) and a `final-exam`
entry. Each section's `content` lists, in order: the section `README.md`,
then for each module its landing page, its parts, and right after the part a
lab tests, a `Question` reading (`labs/lab-0N/question.md`) followed by the
`type: lab` entry; the module's closing page comes last. The section quiz and
then the section capstone close the section. Playgrounds are not listed: the
landing page's `<!-- astrona:playground -->` marker shows them.

Every `type: lab` entry (module labs and capstones) carries these fields, in
this order:

```yaml
      - type: reading
        title: Question
        path: sections/section-010/module-01/labs/lab-01/question.md
      - type: lab
        title: "Install Istio With istioctl Lab"
        path: sections/section-010/module-01/labs/lab-01
        difficulty: beginner
        estimated_duration: 20m
        topic: istioctl-install
        task_kind: build
        tags: [istioctl, profiles, crds, injection-webhook, namespace-injection, version-skew]
        learning_goals:
          - Install a demo-profile control plane from an empty cluster
          - Bring a running workload into the mesh and prove the versions agree
        resources:
          - name: "Install with istioctl"
            url: https://istio.io/latest/docs/setup/install/istioctl/
```

- `difficulty`: `beginner`, `intermediate` or `advanced`.
- `estimated_duration`: realistic time to solve it, for example `15m`, `30m`, `45m`.
- `topic`: exactly one of `istioctl-install`, `helm-install`,
  `customization`, `sidecar-injection`, `helm-upgrade`, `canary-upgrade`,
  `in-place-upgrade`, `ambient`.
- `task_kind`: exactly one of `build` (install or configure from scratch),
  `troubleshooting` (find and fix what is broken) or `migration` (move a
  working setup to another version, revision or data plane mode). The
  platform filters labs by it, so it is a field of its own, never a tag.
- `tags`: 4 to 8 ids, only from the tag list below. Add a new tag to the list
  first if nothing fits.
- `learning_goals`: 2 or 3 plain sentences, each starting with a verb, saying
  what the learner proves in this lab.
- `resources`: 1 to 4 documentation pages, each with a `name` and a `url`
  that loads. This is the **only** place outside links are allowed: the
  platform shows them as optional further reading next to the lab.

**Tag list** (lower case, hyphens, never synonyms):

- Install tools: `istioctl`, `helm`, `istiooperator`, `profiles`,
  `manifest-generate`, `precheck`, `uninstall`
- What an install creates: `crds`, `istiod`, `injection-webhook`,
  `ingress-gateway`, `egress-gateway`, `nodeport`
- Helm: `helm-base`, `helm-istiod`, `helm-gateway`, `helm-values`,
  `helm-release`, `helm-upgrade`, `helm-rollback`, `reuse-values`
- Customization: `meshconfig`, `access-logging`, `outbound-traffic-policy`,
  `proxy-resources`, `component-overlay`, `values-overlay`
- Injection: `sidecar-injection`, `namespace-injection`, `pod-injection`,
  `injection-precedence`, `native-sidecar`, `rollout-restart`
- Upgrades: `version-skew`, `revisions`, `revision-tags`, `default-revision`,
  `canary`, `in-place`, `rollback`
- Ambient: `ambient`, `ztunnel`, `istio-cni`, `hbone`, `waypoint`,
  `use-waypoint`, `gateway-api`, `httproute`, `authorizationpolicy`,
  `l4-policy`, `l7-policy`
- Tools: `istioctl-version`, `proxy-status`, `istioctl-analyze`,
  `ztunnel-config`, `helm-get-values`

### Running things

```bash
# Playground (ungraded)
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-010/module-01/playground
astrona destroy ats-013-playground-010-01   # takes metadata.name from config.yaml, not the path

# Lab or capstone (graded against the live cluster)
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-010/module-01/labs/lab-01
astrona submit -c sections/section-010/module-01/labs/lab-01
astrona destroy ats-013-lab-010-01

# Authors: run a local, uncommitted copy, and prove a lab passes with its reference solution
astrona run -c sections/section-010/module-01/playground
astrona test -c sections/section-010/module-01/labs/lab-01
```

Names (from each `config.yaml` `metadata.name`):

| Kind | Name pattern | Example |
| --- | --- | --- |
| Playground | `ats-013-playground-<section>-<module>` | `ats-013-playground-030-02` |
| Module lab | `ats-013-lab-<section>-<module>` | `ats-013-lab-020-02` |
| Capstone | `ats-013-capstone-<section>` | `ats-013-capstone-040` |

Keep those names. A second lab in a module takes
`ats-013-lab-<section>-<module>-<lab>`, for example `ats-013-lab-040-02-02`,
so two labs never share a name. A lab's `config.yaml` names its docs with
`metadata.docs.question: "question.md"` and `metadata.docs.solution:
"solution.md"`; the platform reads these names, so never rename them, even if
a local `astrona validate` reports them as unknown fields. Lab bootstrap
scripts do not pin a kube context: astrona sets `KUBECONFIG` for the lab, and
`astrona test` runs on a cluster with a different name. Every lab must pass
`astrona validate` and `astrona test`.

Graders check **the live state**: Helm releases and their versions, the mesh
settings in the `istio` ConfigMap, which control plane each proxy is
connected to, container counts, and real traffic where it matters (for
example through a waypoint). A lab's `question.md` and `solution.md` must
match what its `validation/` scripts actually check.

Test clusters on the maintainer's machine: one at a time. Podman has 10 GiB
and also runs the platform stack; parallel clusters run it out of memory.
Never touch clusters you did not create.

### Where to find trusted sources

Check facts here before writing them down. Prefer these over memory. These
links are for authors; course pages still follow "No links to outside
sources".

- **Installing:**
  [Install with istioctl](https://istio.io/latest/docs/setup/install/istioctl/),
  [Install with Helm](https://istio.io/latest/docs/setup/install/helm/),
  [Configuration profiles](https://istio.io/latest/docs/setup/additional-setup/config-profiles/),
  [Customizing the installation](https://istio.io/latest/docs/setup/additional-setup/customize-installation/)
- **Configuration reference:**
  [IstioOperator API](https://istio.io/latest/docs/reference/config/istio.operator.v1alpha1/),
  [Global mesh options (`meshConfig`)](https://istio.io/latest/docs/reference/config/istio.mesh.v1alpha1/),
  [istioctl command reference](https://istio.io/latest/docs/reference/commands/istioctl/)
- **Sidecar injection:**
  <https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/>
- **Upgrading:**
  [Canary upgrades](https://istio.io/latest/docs/setup/upgrade/canary/),
  [In-place upgrades](https://istio.io/latest/docs/setup/upgrade/in-place/),
  [Helm upgrades](https://istio.io/latest/docs/setup/upgrade/helm/),
  [Supported releases and skew](https://istio.io/latest/docs/releases/supported-releases/)
- **Ambient:**
  [Install ambient mode](https://istio.io/latest/docs/ambient/install/),
  [Add workloads to the mesh](https://istio.io/latest/docs/ambient/usage/add-workloads/),
  [Configure waypoint proxies](https://istio.io/latest/docs/ambient/usage/waypoint/)
- **Helm itself:** <https://helm.sh/docs/helm/helm_upgrade/> (value flags)
  and <https://helm.sh/docs/helm/helm_rollback/>.
- **The exam itself:** the ICA page on the Linux Foundation / CNCF training
  site lists the official curriculum. The domain weight (20%) and topic list
  above come from this repository's README and `astrona.yaml` and have not
  been re-checked against it.

### Skills to use here

The `astrona-course-*` skills do most authoring jobs in this repository: planning
(`domain-plan`), creating the tree (`domain-scaffold`), building modules
(`domain-build`), deep-dive parts (`deep-dive`), labs and playgrounds (`lab`),
lab docs (`lab-docs`), challenges (`create-challenge`), quizzes
(`generate-assessment`) and fact-checking (`review-accuracy`).
