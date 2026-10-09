# ATS013 - ICA: Installation, Upgrade And Configuration

Welcome to **ATS013**, a free, hands-on training curriculum built around the **Installation, Upgrade And Configuration** domain of the **Istio Certified Associate (ICA)** exam — 20% of the exam, and the foundation every other domain sits on. This is community training material inspired by the open-source [Istio project](https://istio.io) (a CNCF graduated project); it is not an official Linux Foundation or CNCF exam guide, and no specific vendor exam blueprint is claimed or implied.

Installing a service mesh is where most people's mental model of Istio is formed, and a shaky one costs them for the rest of the exam. This repository covers the whole install-time half: getting a control plane onto a cluster two different ways, shaping it to a cluster's actual needs, deciding precisely which pods join the mesh, upgrading without losing configuration or stranding the data plane, and the sidecar-less ambient data plane alongside the classic one.

Chapters are written against **Istio 1.30.5**, with the upgrade modules moving from **1.29.8** to **1.30.5** so that version skew is something you watch happen rather than read about.

---

## How This Course Is Built

The course opens with an **Introduction** (`sections/intro/`): what the course trains, how to get a machine ready, and how the content is made. After it, every module is built the same way, in four layers:

1. **The reader (`sections/section-XXX/module-YY/course.md` plus its `course-0N-*.md` parts)**: a short landing page, two to four ordered deep-dive parts that explain *why* Istio behaves the way it does, concrete case before general rule, and a closing summary page. Hands-on steps sit inside the prose: what to run and why, the command, the real output, and what it shows.
2. **The playground (`sections/section-XXX/module-YY/playground/`)**: a live **kind** cluster provisioned to exactly the starting state the reader assumes. Ungraded: no task, no `astrona submit`, no pass or fail.
3. **The graded labs (`sections/section-XXX/module-YY/labs/lab-0N`)**: exam-style tasks on a fresh cluster, graded on live cluster state by an automated validator. Each lab comes right after the part it tests, and every lab ships a `question.md` and a full `solution.md` walkthrough.
4. **The section quiz (`sections/section-XXX/quiz.md`)** and a **section capstone** (`sections/section-XXX/capstone/labs/lab-01`) that integrates the whole section.

Once all four sections are done, **`sections/final-domain-quiz.md`** is a closed-book, timed simulation of the whole domain.

---

## Complete Curriculum & Module Mapping

The domain is divided into **4 sections** covering **9 modules** and **30 deep-dive parts**, with **9 playgrounds**, **15 graded module labs**, **4 section capstones**, **4 quizzes** and a final exam simulator:

| Section & Curriculum Item | Module Reader | Graded Labs |
| :--- | :--- | :--- |
| **010: Installing Istio with istioctl or Helm** | [Install Istio With istioctl](sections/section-010/module-01/course.md) — 4 parts | [Install Istio With istioctl](sections/section-010/module-01/labs/lab-01) · [Remove Istio Completely With istioctl](sections/section-010/module-01/labs/lab-02) |
|  | [Install Istio With Helm](sections/section-010/module-02/course.md) — 4 parts | [Install Istio With Helm](sections/section-010/module-02/labs/lab-01) · [Remove An Istio Helm Install Completely](sections/section-010/module-02/labs/lab-02) |
| | **Section capstone** | **[Install And Onboard A Mesh Capstone](sections/section-010/capstone/labs/lab-01)** · [quiz](sections/section-010/quiz.md) |
| **020: Customizing your Istio installation** | [Customize An Istio Installation](sections/section-020/module-01/course.md) — 3 parts | [Customize An Istio Installation](sections/section-020/module-01/labs/lab-01) |
|  | [Control Sidecar Injection](sections/section-020/module-02/course.md) — 3 parts | [Control Sidecar Injection](sections/section-020/module-02/labs/lab-01) · [Exclude A Port From Sidecar Traffic Capture](sections/section-020/module-02/labs/lab-02) |
| | **Section capstone** | **[Shape The Install, Then Choose Who Joins Capstone](sections/section-020/capstone/labs/lab-01)** · [quiz](sections/section-020/quiz.md) |
| **030: Upgrading Istio (canary, in-place)** | [Upgrade And Reconfigure Istio With Helm](sections/section-030/module-01/course.md) — 4 parts | [Upgrade And Reconfigure Istio With Helm](sections/section-030/module-01/labs/lab-01) · [Roll Back A Helm Release Of istiod](sections/section-030/module-01/labs/lab-02) |
|  | [Canary Upgrade With Revisions And Revision Tags](sections/section-030/module-02/course.md) — 4 parts | [Canary Upgrade With Revisions And Tags](sections/section-030/module-02/labs/lab-01) · [Retire The Old Control Plane Revision](sections/section-030/module-02/labs/lab-02) |
|  | [In-Place Upgrade Of The Control Plane](sections/section-030/module-03/course.md) — 3 parts | [In-Place Upgrade](sections/section-030/module-03/labs/lab-01) |
| | **Section capstone** | **[A Complete Canary Migration Capstone](sections/section-030/capstone/labs/lab-01)** · [quiz](sections/section-030/quiz.md) |
| **040: Installing Istio in sidecar or ambient mode** | [Install Istio In Ambient Mode](sections/section-040/module-01/course.md) — 2 parts | [Install Istio In Ambient Mode](sections/section-040/module-01/labs/lab-01) |
|  | [Add A Waypoint Proxy For L7 In Ambient Mode](sections/section-040/module-02/course.md) — 3 parts | [Waypoint Proxy For L7](sections/section-040/module-02/labs/lab-01) · [Scope A Waypoint To One Service](sections/section-040/module-02/labs/lab-02) |
| | **Section capstone** | **[An Ambient Mesh With Selective L7 Capstone](sections/section-040/capstone/labs/lab-01)** · [quiz](sections/section-040/quiz.md) |

Start any playground or lab with `astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c <path>`, for example `-c sections/section-010/module-01/playground`.

---

## How to Navigate This Course

1. **Read the Introduction first.** It covers the tools, the daily `astrona` commands and how a page is laid out.
2. **Enter a section.** Open `sections/section-010/README.md` and read the section's goals before the modules.
3. **Read the module with its playground running.** Each module's landing page starts the playground that its hands-on steps assume.
4. **Take each lab when a part sends you to it.** The part ends with a "Your mission" section that pauses the playground, starts the lab and submits it.
5. **Take the section quiz, then the capstone.** Each section's `quiz.md` checks reasoning before you spend cluster time; the capstone integrates the section.
6. **Simulate the exam.** Once all four sections are done, open `sections/final-domain-quiz.md` and work it under a 25-minute cap, closed book.
7. **Destroy and start over freely.** `astrona destroy <name>` removes an environment; the name is in each lab's `config.yaml`. Rebuilding from clean is cheap and is the fastest way to confirm you can repeat something without the text in front of you.

Section 030's playgrounds arrive with Istio already installed, because sections 010 and 020 teach the install.

---

## Source Material

This curriculum was expanded from a set of per-lab study documents organised by ICA domain rather than by section. Two of them derive from scenarios in the upstream [Killercoda ICA repository](https://github.com/lorenzo85/scenarios-ica); the rest were written from scratch to close curriculum items that repository does not cover. The `sections/` tree is the course and is self-contained — every manifest a lab needs is created inline by its bootstrap scripts or by the reader during the task.

---

## Cluster-Native Focus

Every playground in this repository runs on a **kind** (Kubernetes-in-Docker) cluster spun up by the `astrona` CLI — no virtual machines and no host-level Linux administration. You work through `kubectl`, `istioctl` and `helm` against a real Istio installation, exactly as you would against a production cluster.
