# ATS013 - ICA: Installation, Upgrade And Configuration

Welcome to **ATS013**, a free, hands-on training curriculum built around the **Installation, Upgrade And Configuration** domain of the **Istio Certified Associate (ICA)** exam — 20% of the exam, and the foundation every other domain sits on. This is community training material inspired by the open-source [Istio project](https://istio.io) (a CNCF graduated project); it is not an official Linux Foundation or CNCF exam guide, and no specific vendor exam blueprint is claimed or implied.

Installing a service mesh is where most people's mental model of Istio is formed, and a shaky one costs them for the rest of the exam. This repository covers the whole install-time half: getting a control plane onto a cluster two different ways, shaping it to a cluster's actual needs, deciding precisely which pods join the mesh, upgrading without losing configuration or stranding the data plane, and the sidecar-less ambient data plane alongside the classic one.

Chapters are written against **Istio 1.30.5**, with the upgrade modules moving from **1.29.8** to **1.30.5** so that version skew is something you watch happen rather than read about.

---

## How This Course Is Built

Every module is built the same way, in four layers:

1. **The reader (`sections/section-XXX/module-YY/course.md` plus its `course-0N-*.md` parts)** — a short landing page, two to four ordered deep-dive parts and a wrap-up page that explain *why* Istio behaves the way it does, concrete case before general rule, with a diagram wherever a mechanism has stages.
2. **The playground (`sections/section-XXX/module-YY/playground/`)** — a live **kind** cluster provisioned to exactly the starting state the reader assumes. Parts mix "See it in your playground" steps into the explanation, so you read an idea and immediately watch it run. Ungraded: no task, no `astrona submit`, no pass/fail.
3. **The graded lab (`sections/section-XXX/module-YY/labs/lab-01`)** — an exam-style task on a fresh cluster, graded on live cluster state by an automated validator. Every lab ships a `question.md` and a full `solution.md` walkthrough.
4. **The section quiz (`sections/section-XXX/quiz.md`)** and a **Section Capstone Challenge** (`sections/section-XXX/capstone/labs/lab-01`) that integrates the whole section.

Once all four sections are done, **`sections/final-domain-quiz.md`** is a closed-book, timed simulation of the whole domain.

---

## Complete Curriculum & Module Mapping

The domain is divided into **4 sections** covering **9 modules** and **28 deep-dive parts**, with **9 playgrounds**, **9 graded module labs**, **4 section capstones**, **4 quizzes** and a final exam simulator:

| Section & Curriculum Item | Module Reader | Graded Lab |
| :--- | :--- | :--- |
| **010: Installing Istio with istioctl or Helm** | [M1: Install Istio With istioctl](sections/section-010/module-01/course.md) — 4 parts | [lab](sections/section-010/module-01/labs/lab-01) · `astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-010/module-01/labs/lab-01` |
| | [M2: Install Istio With Helm](sections/section-010/module-02/course.md) — 3 parts | [lab](sections/section-010/module-02/labs/lab-01) · `astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-010/module-02/labs/lab-01` |
| | **Section Capstone Challenge** | **[Install And Onboard A Mesh](sections/section-010/capstone/labs/lab-01)** · [quiz](sections/section-010/quiz.md) |
| **020: Customizing your Istio Installation** | [M1: Customize An Istio Installation](sections/section-020/module-01/course.md) — 3 parts | [lab](sections/section-020/module-01/labs/lab-01) · `astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-020/module-01/labs/lab-01` |
| | [M2: Control Sidecar Injection](sections/section-020/module-02/course.md) — 3 parts | [lab](sections/section-020/module-02/labs/lab-01) · `astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-020/module-02/labs/lab-01` |
| | **Section Capstone Challenge** | **[Shape The Install, Then Choose Who Joins](sections/section-020/capstone/labs/lab-01)** · [quiz](sections/section-020/quiz.md) |
| **030: Upgrading Istio (Canary, In-Place)** | [M1: Upgrade And Reconfigure Istio With Helm](sections/section-030/module-01/course.md) — 4 parts | [lab](sections/section-030/module-01/labs/lab-01) · `astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-030/module-01/labs/lab-01` |
| | [M2: Canary Upgrade With Revisions And Revision Tags](sections/section-030/module-02/course.md) — 4 parts | [lab](sections/section-030/module-02/labs/lab-01) · `astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-030/module-02/labs/lab-01` |
| | [M3: In-Place Upgrade Of The Control Plane](sections/section-030/module-03/course.md) — 2 parts | [lab](sections/section-030/module-03/labs/lab-01) · `astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-030/module-03/labs/lab-01` |
| | **Section Capstone Challenge** | **[A Complete Canary Migration](sections/section-030/capstone/labs/lab-01)** · [quiz](sections/section-030/quiz.md) |
| **040: Installing Istio in Sidecar or Ambient Mode** | [M1: Install Istio In Ambient Mode](sections/section-040/module-01/course.md) — 2 parts | [lab](sections/section-040/module-01/labs/lab-01) · `astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-040/module-01/labs/lab-01` |
| | [M2: Add A Waypoint Proxy For L7 In Ambient Mode](sections/section-040/module-02/course.md) — 3 parts | [lab](sections/section-040/module-02/labs/lab-01) · `astrona run --git git@github.com:astrona-io/ATS013.git -c sections/section-040/module-02/labs/lab-01` |
| | **Section Capstone Challenge** | **[An Ambient Mesh With Selective L7](sections/section-040/capstone/labs/lab-01)** · [quiz](sections/section-040/quiz.md) |

---

## How to Navigate This Course

1. **Enter a section portal.** Open `sections/section-010/README.md` and read the section's competencies before the modules.
2. **Read the chapter.** Work through `module-01/course.md`, then `module-02/course.md`, in order.
3. **Run the playground alongside it.** Each module's landing page launches the playground that its hands-on steps assume. Start it before you begin reading.
4. **Try things the chapter did not.** Every playground's `docs/overview.md` lists open-ended things to explore once the chapter is done. That is where the chapter's knowledge turns into recall.
5. **Take the section quiz, then the labs.** Each section's `quiz.md` checks diagnostic reasoning before you spend cluster time; the module labs then grade the skill on live state, and the capstone integrates the section.
6. **Simulate the exam.** Once all four sections are done, open `sections/final-domain-quiz.md` and work it under a 25-minute cap, closed book.
7. **Destroy and start over freely.** `astrona destroy <name>` tears an environment down; the name is on each module's wrap-up page. Rebuilding from clean is cheap and is the fastest way to confirm you can repeat something without the text in front of you.

Sections are ordered so that each one's playground assumes the previous section's skills. Section 030's playgrounds arrive with Istio already installed because sections 010 and 020 taught you to install it.

---

## Source Material

This curriculum was expanded from a set of per-lab study documents organised by ICA domain rather than by section. Two of them derive from scenarios in the upstream [Killercoda ICA repository](https://github.com/lorenzo85/scenarios-ica); the rest were written from scratch to close curriculum items that repository does not cover. The `sections/` tree is the course and is self-contained — every manifest a lab needs is created inline by its bootstrap scripts or by the reader during the task.

---

## Cluster-Native Focus

Every playground in this repository runs on a **kind** (Kubernetes-in-Docker) cluster spun up by the `astrona` CLI — no virtual machines and no host-level Linux administration. You work through `kubectl`, `istioctl` and `helm` against a real Istio installation, exactly as you would against a production cluster.
