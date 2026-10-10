# How This Course Is Made

You will trust a course more when you know how it is built. This page tells you how the content is written and checked, who is behind it, and how you can help make it better.

## How the content is written

The course targets one version of Istio. Everything is built and checked on **Istio 1.30.5**, and the upgrade section also uses **1.29.8** as the starting version. When a page says how Istio behaves, it means those versions.

Facts come from real sources. They are checked against the official Istio documentation, in particular the install pages for `istioctl` and Helm, the configuration profiles, the `IstioOperator` and mesh configuration references, the sidecar injection page, the canary and in-place upgrade pages, and the ambient mode pages. Each page then explains everything you need on the page itself, so you never have to leave the course to look something up.

Command output is real, too. When a page shows output, it comes from a real run. If the output is shortened, the page says so. If there was no real run to copy from, the page describes the result in words instead of making up output.

The same care goes into the graded labs, because their graders check the live cluster. A grader reads what is really running, for example the version of `istiod` and of each proxy, the Helm release history, or the mesh settings, and it sends real requests where it matters. Many graders also reject a shortcut that only looks right, such as deleting and recreating a Deployment instead of restarting it. Each lab also has a reference solution that is run against its own grader, so the grader is known to accept a correct answer.

The pages are written in plain English, for people who are not native English speakers and have no university degree. Words are written out in full, and each technical term gets a short, plain definition the first time it appears. The pages use the real technical terms, not metaphors, because those are the words you meet in the product, the logs and the exam.

Finally, large parts of this course are drafted and edited with the help of AI tools. A maintainer reviews every change before it is published, and the technical checks above apply to all content, however it was written.

## Maintainers

A small group of people builds and looks after the course. The core maintainer is **Paris Nakita Kejser** ([@parisnakitakejser](https://github.com/parisnakitakejser)).

Many others have helped along the way. Every person who has changed the course is listed on the GitHub contributors page:
[github.com/astrona-io/ATS013/graphs/contributors](https://github.com/astrona-io/ATS013/graphs/contributors)

## Found a mistake? Report it

Even with these checks, mistakes slip through. If a command fails, a page says something wrong, or a lab grades a correct answer as wrong, please tell us. Every report makes the course better for the next learner. A good report takes four steps:

1. Open a new issue on GitHub: [github.com/astrona-io/ATS013/issues](https://github.com/astrona-io/ATS013/issues).
2. Say which page or lab it is (the file path is the easiest, for example `sections/section-010/module-01/labs/lab-01`).
3. Paste the command you ran and what you saw. Leave out passwords, tokens, private keys or anything else private.
4. Say what you expected to happen instead.

Want to fix it yourself? Pull requests are welcome on the same repository.

## License

The course is published under the [Apache License 2.0](https://github.com/astrona-io/ATS013/blob/main/LICENSE). You are welcome to use it, share it and build on it under the terms of that license.
