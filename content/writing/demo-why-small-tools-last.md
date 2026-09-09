---
title: "Why Small Tools Last"
description: "A few notes on software that stays useful by refusing to become a platform."
date: 2026-08-24
slug: "why-small-tools-last"
demo: true
---

The tools I keep returning to usually do one thing, expose their seams, and
leave the rest of the system alone. They accept plain input, produce plain
output, and make no claim on how I should arrange the work around them.

That modesty is a technical feature. A small tool is easier to replace, but it
is also less likely to *need* replacing. Its value lives in the contract rather
than in a surrounding account, dashboard, or workflow.

## Boring interfaces compound

Text streams, files, and exit codes are not exciting interfaces. They survive
because they are easy to inspect and easy to connect. When a tool emits
something another program can read without a special client, it gains uses its
author did not have to predict.

There is a useful discipline here: make the center solid and the edges loose.
The center should do its job carefully. The edges should make as few decisions
for the user as possible.

## The maintenance test

Before adding another mode, I like to ask three questions:

1. Does this belong to the tool, or merely near it?
2. Can the same result be reached by composing two existing pieces?
3. Will someone understand the new behavior from `--help` alone?

If the third answer is no, the feature may still be worthwhile. It is also a
warning that the tool is beginning to require a map.

Small software is not automatically good software. But small boundaries are
often what let good software remain understandable long enough to become old.
