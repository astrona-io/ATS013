# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Plain English

Write the text in Plain English for a general adult audience (18+) without a
university degree. The content must be highly accessible and easy to
understand for non-technical readers, without feeling childish.

Strict guidelines:

1. Target a Flesch-Kincaid Grade Level of 8 or 9 (equivalent to a standard
   newspaper article).
2. Avoid all technical jargon, acronyms, and corporate buzzwords. If a
   technical term is necessary, explain it immediately using an everyday
   analogy.
3. Keep sentences conversational and direct. Split long sentences into two.
4. Use short paragraphs (max 3-4 sentences per paragraph) and clear
   subheadings to make the text scannable.
5. Use the active voice (e.g., "We did this" instead of "This was done by us").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page and a few
  deep-dive parts. The landing page is a map: goals, what to know first, the
  order of the parts, where it fits. The real teaching goes in the parts. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, renumber the files, fix every "Part N"
  reference in the module, the wrap-up links and `astrona.yaml`.
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
  need Istio installed with the `demo` profile"). The wrap-up page is the one
  exception: it recaps each part and links to it.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Keep them, but explain
  each one in plain words, with an everyday analogy, the first time it appears
  in a file. Spell out acronyms on first use, with a short plain meaning.
- **Analogies come from space, and the reader is an astronaut.** When a term
  needs an everyday picture, use space: spaceships, planets, solar systems,
  space stations, mission control, signals, docking, star charts, airlocks,
  even the Death Star. Talk to the reader as an astronaut (for example "your
  first mission", "astronaut, check your flight log"), but not in every
  sentence. Requests are **signals** that ships send to each other. Use one
  analogy per hard idea, keep it short, and keep it the same everywhere (if
  the repository has an analogy glossary, use it). The analogy helps the reader; it
  never replaces the real term, and it never changes code or output.
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
- **Keep the page furniture the same.** Hands-on steps are normal page
  content, not boxes: a short `###` subsection (for example "See it in your
  playground") with one sentence saying what to do, the command, the real
  output, and one or two sentences saying what it shows. A `> [!TIP]` box is
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
  `astrona destroy <lab name>` plus `astrona start <playground name>`. The
  wrap-up lists the missions and ends with cleaning up the playground
  (`astrona list`, `astrona destroy <playground name>`).
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), wrap-up pages or pages without commands.
- **Mermaid without HTML.** The platform renders Mermaid with HTML labels
  switched off, so `<br/>` and any other HTML tag break the drawing. Rules:
  - One line per box, no `<br/>`, no HTML. Keep the box to the thing's name
    (`"istio-base"`, `"istiod"`, `"Service: notification-service"`).
  - Put the logic on the arrows: `B -->|"CRDs first"| I`,
    `I -->|"webhook"| P`, `N -->|"istio.io/rev: canary"| R`. Keep edge labels short.
  - Quote every label. Prefer `flowchart TB`; use `LR` only for a short chain.
  - Sequence diagrams: short participant aliases (`participant T as tester`)
    and short message text.
  - Anything longer (cluster names, full hostnames) goes in the sentence under
    the diagram.
- **No links to outside sources.** Course pages, labs and playground docs do
  not link to or point at outside websites (the one exception is the
  `resources` field of a lab entry in `astrona.yaml`) (official docs, GitHub, blogs,
  RFCs), and they have no "Reference" or "Official docs" lists. Everything the
  reader needs is explained on the page itself. Not affected: addresses the
  reader actually uses in a command or browser (`http://127.0.0.1:9080`,
  `curl https://httpbin.org`), and the Mission Briefing's contributors and
  "report a mistake" links.
- **Configuration goes to a file first.** Whenever the reader should apply
  YAML (course parts, playground docs, labs), use three separate steps:
  1. "Save this as `namespace-mesh-demo.yaml`:" followed by a plain
     ` ```yaml ` block with only the YAML. No `cat > file <<'EOF'`, no
     `kubectl apply -f - <<EOF`, no shell around it.
  2. "Apply it:" followed by a ` ```sh ` block with only
     `kubectl apply -f namespace-mesh-demo.yaml`.
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
section is only true for this one.

### What the student is trying to learn

- **The goal:** pass the **Installation, Upgrade And Configuration** domain
  of the **Istio Certified Associate (ICA)** exam. It is 20% of the exam, and
  every other domain sits on top of it.
- **What the exam really tests:** installing, shaping and upgrading Istio by
  hand, on a live cluster, under time pressure, and proving it worked. So the
  student must *do* things (install with `istioctl` and with Helm, change
  mesh settings, choose which pods get a sidecar, move workloads to a new
  control plane, switch on ambient mode), not just recognise words. Every
  explanation should lead to something they can run, and every change should
  be proved with a command that shows the new state (`istioctl version`,
  `istioctl proxy-status`, `helm list`, a pod's container count).
- **The four exam topics (curriculum items):** installing Istio with
  `istioctl` or Helm, customizing the Istio installation, upgrading Istio
  (canary and in-place), and installing Istio in sidecar or ambient mode.
  Each section covers exactly one of them.
- **The sections:**

  | Section | Title | Exam topic |
  | --- | --- | --- |
  | 010 | Installing Istio With istioctl Or Helm | Installing Istio with istioctl or Helm |
  | 020 | Customizing Your Istio Installation | Customizing your Istio installation |
  | 030 | Upgrading Istio (Canary, In-Place) | Upgrading Istio (canary, in-place) |
  | 040 | Installing Istio In Sidecar Or Ambient Mode | Installing Istio in sidecar or ambient mode |

- **The version:** everything is built and checked on **Istio 1.30.5** on a
  single-node `kind` cluster. The upgrade section (030) starts on **1.29.8**
  and moves to **1.30.5**, so version skew is something the learner watches
  happen. Do not teach fields or behaviour from other versions without
  saying so. There is no in-cluster Istio operator in these versions:
  `istioctl install` renders and applies on the learner's machine.
- **The main sources:** the Istio install pages,
  <https://istio.io/latest/docs/setup/install/>, the upgrade pages,
  <https://istio.io/latest/docs/setup/upgrade/>, and the ambient install
  pages. Check every page against them.

### Space analogy glossary

Use these pictures for these terms, in every course page, lab and playground.
Keep them consistent so the astronaut builds one picture of the universe.
They are the same pictures as in the other Istio courses (ATS014, ATS015),
plus the ones this domain needs to talk about building and replacing mission
control. Most pages written before these rules have no space analogies yet;
add them when you rework a page, using this table.

**The universe**

| Term | Space picture |
| --- | --- |
| The learner | An astronaut (a cadet on their first missions) |
| Kubernetes cluster | A solar system |
| Namespace | A planet in that solar system |
| Pod | A spaceship |
| Container | A module inside the ship (the app is the crew) |
| Kubernetes Service | A beacon: one call sign that a whole group of ships answers to |
| Request / response | A signal sent out, and the reply signal |
| Port | A radio channel |
| Service mesh | The fleet's shared signal network |
| `kind` cluster on your laptop | A training solar system in the simulator |
| Kubernetes API server | The solar system's registry office: every object is filed there |
| Custom Resource Definition (CRD) | A new form the registry office learns to accept (a new kind of object) |
| Admission webhook | A dock inspector the registry office calls before it files a new ship |

**The mesh**

| Term | Space picture |
| --- | --- |
| Sidecar proxy (Envoy) | The ship's communications officer: every signal in or out goes through them |
| Sidecar injection | Putting a communications officer on board when the ship launches (ships already flying do not get one) |
| Injection webhook (`istio-sidecar-injector`) | The dock inspector who adds the communications officer to each new ship |
| `istio-injection=enabled` namespace label | A planet-wide order: every new ship launched here gets a communications officer |
| `sidecar.istio.io/inject` pod label | One ship's own request, which beats the planet-wide order |
| Native sidecar (init container with `restartPolicy: Always`) | The communications officer boards before the crew and stays for the whole flight |
| `istio-init` / Istio CNI plugin | The dock crew who rewire the ship's radio so every signal passes the communications officer |
| `istiod` (control plane) | Mission control: it sends every communications officer their orders and issues ID badges |
| xDS push | Mission control radioing new orders to every ship in flight, no landing needed (no restart) |
| `meshConfig` / the `istio` ConfigMap | The fleet's standing orders, pinned on mission control's notice board |
| `values.global.proxy` (proxy resources, image) | The standard kit every communications officer is issued |
| Ingress / egress gateway | The spaceport arrival gate / departure gate |

**Building mission control (installation)**

| Term | Space picture |
| --- | --- |
| `istioctl` | Your launch console: you operate it by hand |
| `istioctl install` (render and apply) | The console draws a complete blueprint on your machine, then builds the solar system to match it |
| `IstioOperator` document | The blueprint itself: an input, not a building that watches anything |
| Profile (`default`, `demo`, `minimal`, `ambient`) | A stock blueprint from the shipyard catalogue |
| Overlay (`-f` file, `--set` flag) | Notes pinned on top of the blueprint; a `--set` note always wins |
| `istioctl manifest generate` | Printing the blueprint without building anything |
| `istioctl x precheck` | The pre-flight check of the launch pad, before you build |
| Pruning / reconciliation | Anything the new blueprint does not show gets taken down |
| `istioctl uninstall --purge` | Demolishing every Istio building, foundations included |
| Helm chart | A flat-pack kit from the shipyard |
| Helm release | One kit, assembled in your solar system under a name, with a numbered logbook |
| `istio/base` chart (CRDs) | The foundations: the registry office must learn the new forms before anything else is built |
| `istio/istiod`, `istio/gateway` charts | Mission control, and a spaceport gate, each built from its own kit |
| Helm values file | The order form for a kit |
| Release history (`helm history`, the release Secret) | The logbook: one page per build of that kit |

**Replacing mission control (upgrades)**

| Term | Space picture |
| --- | --- |
| Version skew (client, control plane, data plane) | Your console, mission control and the communications officers running different software versions |
| `istioctl version` / `istioctl proxy-status` | A roll call: who runs which version, and who is in contact with mission control |
| `helm upgrade` value handling (`--reuse-values`, `--reset-then-reuse-values`) | Copying last time's order form, or starting from the kit's blank form and copying your own notes onto it |
| `helm rollback` | Rebuilding the kit from an older logbook page |
| In-place upgrade | Replacing mission control in the same building; ships keep the old orders until they relaunch |
| Canary upgrade | Building a second mission control next to the first and moving planets over one at a time |
| Revision (`--revision`, `istiod-<revision>`) | A named mission control, so two can run side by side |
| `istio.io/rev` namespace label | Which mission control a planet reports to |
| Revision tag (for example `prod`) | A call sign that points at one mission control; move the call sign and planets follow at their next launch |
| `defaultRevision` / `default` tag | The mission control that answers planets with the plain `istio-injection=enabled` order |
| `kubectl rollout restart` | Relaunching the ships so each gets a fresh communications officer |

**Ambient mode (section 040)**

| Term | Space picture |
| --- | --- |
| Ambient mode | Ships fly without their own communications officer; shared relay towers do the job instead |
| ztunnel | A shared relay tower, one per node (launch pad), for every ship docked there: it does the handshake and checks badges, but cannot read the signal's contents |
| `istio-cni` node agent | The dock crew at every launch pad who connect each ship's radio to the relay tower |
| `istio.io/dataplane-mode=ambient` label | A planet-wide order: every ship here, new or already flying, uses the relay towers |
| HBONE | The sealed tunnel the relay towers use between them |
| Waypoint | A checkpoint station you build only where someone must read the signal's contents (L7 rules) |
| `istio.io/use-waypoint` label | Telling a beacon or planet to route its signals through the checkpoint station |
| Gateway API CRDs | The forms a checkpoint station is filed on; the registry office must know them first |
| L4 rule vs L7 rule | Checking the envelope (who, which channel) vs reading the letter (path, method, headers) |

### The sample apps the playgrounds and labs use

This course is about the mesh itself, not about an application, so its
workloads are small stand-ins. Their names come from the code and **stay as
they are**: never rename them in commands, YAML or output. The Starfleet
names from the other Istio courses (`bridge`, `scout`, `shuttle`) do **not**
exist here. In prose you may still use the pictures from the glossary (for
example "the `tester` ship is your test shuttle"), but always next to the
real name.

| Kubernetes name | Image | What it is | Where |
| --- | --- | --- | --- |
| `notification-service` (Deployment and Service, port `80`) | `nginx:1.27-alpine` | A ship that answers every signal; the main workload in most modules | Most playgrounds and labs; `notification-service-v1` is the Deployment name in the upgrade and ambient playgrounds |
| `tester` | `curlimages/curl:8.11.1` | Your test shuttle: every test signal is sent from here | Upgrade playground 030-03, ambient playgrounds, some labs |
| `logging-agent`, `batch-job` | `busybox:1.36` | Ships with no network job, used to show injection choices | `inject-demo` (section 020, module 2) |
| `checkout-api`, `batch-runner`, `audit-shipper`, `nightly-report`, `order-api` | `nginx` / `busybox` / `curl` | The capstone fleets | `payments`, `legacy`, `orders` namespaces in the capstones |
| `catalog-api`, `storefront` | `nginx` / `curl` | The ambient capstone fleet | `ambient-shop` (section 040 capstone) |

The planets (namespaces) are named after the module: `mesh-demo`,
`inject-demo`, `canary-demo`, `inplace-demo`, `ambient-demo`, `ambient-l7`,
plus `istio-system` (mission control) and `istio-ingress` (the gateway's own
planet in the Helm installs). The section 030 module 1 playground runs
`notification-service` in `default`.

### Environment facts the text must respect

- **Where Istio comes from.** Every playground and lab downloads Istio with
  `curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION=... sh -` and
  copies `istioctl` to `/usr/local/bin`, or to `$HOME/.local/bin` when that
  is not writable. If `istioctl` is "not found", the fix is
  `export PATH="$HOME/.local/bin:$PATH"`.
- **Starting states differ per module, on purpose.**
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
- **Install documents are applied with the installer.** The "save to a file,
  then apply" rule still holds, but the apply step for an `IstioOperator`
  file is `istioctl install -f <file> -y`, and for a values file it is
  `helm install` or `helm upgrade` with `-f <file>`.
- **One owner per cluster.** A cluster is installed with `istioctl` or with
  Helm, never both. Pages must not mix the two on one cluster.

### Where things are in this repo

| What | Where |
| --- | --- |
| Course outline the platform reads: every reading page and lab, in order. Never list `solution.md` here | `astrona.yaml` |
| Overview, sections table, how to run things | `README.md` |
| Section overview and its modules | `sections/section-0N0/README.md` |
| Module reading: landing page, deep-dive parts, wrap-up | `sections/section-0N0/module-0M/course.md`, `course-0N-*.md` |
| Graded lab: task, walkthrough, setup, grader | `.../labs/lab-0N/` (`question.md`, `solution.md`, `bootstrap/`, `solution/apply.sh`, `validation/`) |
| Ungraded sandbox for a module | `.../playground/` (`config.yaml`, `bootstrap/prepare.sh`, `docs/overview.md` says what is in the box) |
| One graded integration lab per section | `sections/section-0N0/capstone/labs/lab-01/` |
| Section knowledge check (multiple choice) | `sections/section-0N0/quiz.md` |
| Closed-book simulation of the whole domain | `sections/final-domain-quiz.md` |
| Leftover copies of files the pages tell the learner to create (nothing reads them from here) | `istio-custom.yaml`, `istiod-values.yaml`, `catalog-*.yaml`, `notification-header.yaml` |

A lab folder holds:

| Path | Purpose |
| --- | --- |
| `config.yaml` | Lab definition; `metadata.docs` has `question: "question.md"` and `solution: "solution.md"` |
| `README.md` | Short intro with `estimated_duration` front matter and the run, submit and destroy commands |
| `question.md` | The exam-style task. Starts with `# Question` and `Solve this question on: \`terminal\`` |
| `solution.md` | Step-by-step walkthrough with real output |
| `bootstrap/01-*.sh`, `bootstrap/02-*.sh` | Tooling, Istio install where the task needs it, and the starting workloads; never the graded end state |
| `solution/apply.sh` | Reference end state, applied only by `astrona test` |
| `validation/validate-completed.sh` | Grading against the live cluster |

### Lab metadata in `astrona.yaml`

`astrona.yaml` has one entry per section under `modules:` (`module-010`,
`module-020`, `module-030`, `module-040`) and a `final-exam` entry. Each
section's `content` lists, in order: the section `README.md`, then for each
module its landing page, its parts, and right after the part a lab tests, a
`Question` reading (`labs/lab-0N/question.md`) followed by the `type: lab`
entry; the module's wrap-up page comes last. The section quiz and then the
section capstone close the section. Playgrounds are not listed: the landing
page's `<!-- astrona:playground -->` marker shows them.

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
- `task_kind`: exactly one of `build` (install or configure from
  scratch), `troubleshooting` (find and fix what is broken) or `migration`
  (move a working setup to another version, revision or data plane mode).
  The platform filters labs by it, so it is a field of its own, never a tag.
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

A lab's `config.yaml` names its docs with `metadata.docs.question:
"question.md"` and `metadata.docs.solution: "solution.md"`. The platform
reads these names to show the task and the solution. Never rename them,
even if a local `astrona validate` reports them as unknown fields.

Keep those names. A new, second lab in a module takes
`ats-013-lab-<section>-<module>-<lab>`, for example `ats-013-lab-040-02-02`,
so two labs never share a name. Lab bootstrap scripts do not pin a kube
context: astrona sets `KUBECONFIG` for the lab, and `astrona test` runs on a
cluster with a different name. Every lab must pass `astrona validate` and
`astrona test`.

Graders check **the live state**: releases and their versions, the
ConfigMap mesh settings, which control plane each proxy is connected to,
container counts, and real traffic where it matters (for example through a
waypoint). A lab's `question.md` and `solution.md` must match what its
`validation/` scripts actually check.

Test clusters on the maintainer's machine: one at a time. Podman has 10 GiB
and also runs the platform stack; parallel clusters run it out of memory.
Never touch clusters you did not create.

### Where to find trusted sources

Check facts here before writing them down. Prefer these over memory.

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
